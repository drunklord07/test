#!/bin/bash

# Description and Criteria
description="AWS EBS Volume Tagging Audit"
criteria="This script lists all EBS volumes across multiple AWS regions and checks if they have name tags defined.
If an EBS volume does not have a name tag, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-volumes --region \$REGION --query 'Volumes[*].Tags'"

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

    volumes=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" --query 'Volumes[*].[VolumeId, Tags]' --output json)

    echo "--------------------------------------------------"
    echo "| Volume ID         | Name Tag Status            |"
    echo "--------------------------------------------------"

    echo "$volumes" | jq -c '.[]' | while read -r volume; do
      vol_id=$(echo "$volume" | jq -r '.[0]')
      tags=$(echo "$volume" | jq -r '.[1]')

      if [ "$tags" == "null" ]; then
        echo -e "| $vol_id | ${RED} Non-Compliant (No Name Tag)${NC} |"
      else
        name_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Name") | .Value')
        if [ -n "$name_tag" ]; then
          echo -e "| $vol_id | ${GREEN} Compliant (Name: $name_tag)${NC} |"
        else
          echo -e "| $vol_id | ${RED} Non-Compliant (No Name Tag)${NC} |"
        fi
      fi
    done

    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AWS EBS volumes."
