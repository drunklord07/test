#!/bin/bash

# Description and Criteria
description="AWS Web-Tier EBS Volume Encryption Audit"
criteria="This script lists all web-tier EBS volumes based on a specific tag and checks if they are encrypted.
If a volume is unencrypted, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-volumes --region \$REGION --filters Name=tag:\$TAG_NAME,Values=\$TAG_VALUE --query 'Volumes[*].VolumeId'
  3. aws ec2 describe-volumes --region \$REGION --volume-ids \$VOLUME_ID --query 'Volumes[*].Encrypted'"

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

# Set the tag key and value for identifying web-tier volumes
TAG_NAME="web_tier_tag"
TAG_VALUE="web_tier_tag_value"

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+-----------------+"
echo "| Region        | Total Volumes   |"
echo "+----------------+-----------------+"

# Loop through each region and count EBS volumes
declare -A region_vol_count
for REGION in $regions; do
  volume_count=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
    --filters Name=tag:"$TAG_NAME",Values="$TAG_VALUE" \
    --query 'length(Volumes)' --output text)

  if [ "$volume_count" == "None" ]; then
    volume_count=0
  fi

  region_vol_count[$REGION]=$volume_count
  printf "| %-14s | %-15s |\n" "$REGION" "$volume_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with web-tier volumes
for REGION in "${!region_vol_count[@]}"; do
  if [ "${region_vol_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    volumes=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
      --filters Name=tag:"$TAG_NAME",Values="$TAG_VALUE" \
      --query 'Volumes[*].VolumeId' --output text)

    while read -r volume_id; do
      encrypted=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
        --volume-ids "$volume_id" --query 'Volumes[*].Encrypted' --output text)

      echo "--------------------------------------------------"
      echo "Volume ID: $volume_id"
      if [ "$encrypted" == "False" ]; then
        echo -e "Status: ${RED} Non-Compliant (Not Encrypted)${NC}"
      else
        echo -e "Status: ${GREEN} Compliant (Encrypted)${NC}"
      fi
    done <<< "$volumes"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with web-tier EBS volumes."
