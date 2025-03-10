#!/bin/bash

# Description and Criteria
description="AWS AMI Tagging Audit"
criteria="This script lists all AMIs owned by the account and checks if they have name tags.
If an AMI lacks a name tag, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].{ID:ImageId,Tags:Tags}'"

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
echo "| Region        | Total AMIs       |"
echo "+----------------+-----------------+"

# Loop through each region and count AMIs
declare -A region_ami_count
for REGION in $regions; do
  ami_count=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self \
    --query 'length(Images)' --output text)

  if [ "$ami_count" == "None" ]; then
    ami_count=0
  fi

  region_ami_count[$REGION]=$ami_count
  printf "| %-14s | %-15s |\n" "$REGION" "$ami_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with AMIs
for REGION in "${!region_ami_count[@]}"; do
  if [ "${region_ami_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    images=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self \
      --query 'Images[*].{ID:ImageId,Tags:Tags}' --output json)

    echo "$images" | jq -c '.[]' | while read -r image; do
      image_id=$(echo "$image" | jq -r '.ID')
      tags=$(echo "$image" | jq -r '.Tags // empty')

      echo "--------------------------------------------------"
      echo "AMI ID: $image_id"
      if [ -z "$tags" ]; then
        echo -e "Status: ${RED} Non-Compliant (No Tags)${NC}"
      else
        echo -e "Status: ${GREEN} Compliant (Tagged)${NC}"
      fi
    done
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AMIs."
