#!/bin/bash

# Description and Criteria
description="AWS Unused EBS Volume Audit"
criteria="This script lists all EBS volumes across multiple AWS regions and checks if they are in the 'available' state.
If an EBS volume is 'available', it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-volumes --region \$REGION --query 'Volumes[*].VolumeId'
  3. aws ec2 describe-volumes --region \$REGION --volume-ids \$vol_id --query 'Volumes[*].State'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display description, criteria, and the command being used
echo ""
echo "---------------------------------------------------------------------"
echo -e "${PURPLE}Description: $description${NC}"
echo ""
echo -e "${PURPLE}Criteria: $criteria${NC}"
echo ""
echo -e "${PURPLE}$command_used${NC}"
echo "---------------------------------------------------------------------"
echo ""

# Set AWS CLI profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+-----------------+"
echo "| Region        | Total Volumes   |"
echo "+----------------+-----------------+"

# Loop through each region and count EBS volumes
declare -A region_vol_count
for REGION in $regions; do
  vol_count=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" --query 'length(Volumes)' --output text)

  if [ "$vol_count" == "None" ]; then
    vol_count=0
  fi

  region_vol_count[$REGION]=$vol_count
  printf "| %-14s | %-15s |\n" "$REGION" "$vol_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with EBS volumes
for REGION in "${!region_vol_count[@]}"; do
  if [ "${region_vol_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    volumes=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" --query 'Volumes[*].[VolumeId, State]' --output json)

    echo "--------------------------------------------------"
    echo "| Volume ID         | State       | Compliance   |"
    echo "--------------------------------------------------"

    echo "$volumes" | jq -c '.[]' | while read -r volume; do
      vol_id=$(echo "$volume" | jq -r '.[0]')
      state=$(echo "$volume" | jq -r '.[1]')

      if [ "$state" == "available" ]; then
        echo -e "| $vol_id | $state | ${RED} Non-Compliant (Unused)${NC} |"
      else
        echo -e "| $vol_id | $state | ${GREEN} Compliant (In Use)${NC} |"
      fi
    done

    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AWS EBS volumes."
