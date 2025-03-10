#!/bin/bash

# Description and Criteria
description="AWS Audit for Publicly Shared AMIs"
criteria="This script checks if any Amazon Machine Images (AMIs) owned by the account are publicly shared."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId' --output text
  3. aws ec2 describe-images --region \$REGION --image-ids \$AMI_ID --owners self --query 'Images[*].Public' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display script metadata
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
echo "Region         | Publicly Shared AMIs"
echo "+--------------+--------------------------------+"

# Dictionary to store non-compliant AMIs
declare -A public_amis

# Audit each region
for REGION in $regions; do
  # Get all AMIs owned by the account
  ami_ids=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
    --query 'Images[*].ImageId' --output text)

  if [[ -z "$ami_ids" ]]; then
    printf "| %-14s | ${GREEN}No AMIs found${NC}                  |\n" "$REGION"
    continue
  fi

  non_compliant=()
  for AMI_ID in $ami_ids; do
    # Check if the AMI is publicly shared
    public_status=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
      --image-ids "$AMI_ID" --query 'Images[*].Public' --output text)

    if [[ "$public_status" == "True" ]]; then
      non_compliant+=("$AMI_ID")
    fi
  done

  if [[ ${#non_compliant[@]} -gt 0 ]]; then
    public_amis["$REGION"]="${non_compliant[*]}"
    printf "| %-14s | ${RED}%-24s${NC} |\n" "$REGION" "$(echo "${non_compliant[*]}" | wc -w) Public AMI(s)"
  else
    printf "| %-14s | ${GREEN}All AMIs are private${NC}          |\n" "$REGION"
  fi
done

echo "+--------------+--------------------------------+"
echo ""

# Audit Section
if [ ${#public_amis[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Publicly Shared AMIs:${NC}"
  echo "------------------------------------------------------------"

  for region in "${!public_amis[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Publicly Shared AMIs:"
    echo -e "${public_amis[$region]}" | awk '{print " - " $0}'
    echo "------------------------------------------------------------"
  done
else
  echo -e "${GREEN}All AMIs are private.${NC}"
fi

echo "Audit completed for all regions."
