#!/bin/bash

# Description and Criteria
description="AWS EBS Volume Encryption Audit"
criteria="This script lists all EBS volumes across multiple AWS regions and checks if they are encrypted.
Only non-compliant (unencrypted) volumes are displayed in the audit section."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-volumes --region \$REGION --query 'Volumes[*].VolumeId'
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

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo -e "\n+----------------+-----------------+"
echo -e "| Region        | Total Volumes   |"
echo -e "+----------------+-----------------+"

# Loop through each region and count EBS volumes
declare -A region_vol_count
for REGION in $regions; do
  volume_count=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
    --query 'length(Volumes)' --output text)

  if [ "$volume_count" == "None" ] || [ -z "$volume_count" ]; then
    volume_count=0
  fi

  region_vol_count[$REGION]=$volume_count
  printf "| %-14s | %-15s |\n" "$REGION" "$volume_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with EBS volumes
for REGION in "${!region_vol_count[@]}"; do
  if [ "${region_vol_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    # Fetch all volume IDs (ensure each ID is on a new line)
    volumes=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
      --query 'Volumes[*].VolumeId' --output text | tr ' ' '\n')

    if [ -z "$volumes" ]; then
      echo "No volumes found in this region."
      continue
    fi

    non_compliant_found=false
    while read -r volume_id; do
      encrypted=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
        --volume-ids "$volume_id" --query 'Volumes[*].Encrypted' --output text)

      if [ "$encrypted" == "False" ]; then
        if [ "$non_compliant_found" == "false" ]; then
          echo "--------------------------------------------------"
          echo -e "${RED}Non-Compliant Volumes in region: $REGION${NC}"
          echo "--------------------------------------------------"
          non_compliant_found=true
        fi
        echo "Volume ID: $volume_id"
      fi
    done <<< "$volumes"

    if [ "$non_compliant_found" == "true" ]; then
      echo "--------------------------------------------------"
    fi
  fi
done

echo "Audit completed for all regions with EBS volumes."
