#!/bin/bash

# Description and Criteria
description="AWS Audit for KMS Customer Master Key (CMK) Tag Compliance"
criteria="This script checks if each AWS KMS CMK has tags assigned."

# Commands used
command_used="Commands Used:
  1. aws kms list-keys --region \$REGION --query 'Keys[*].KeyId' --output text
  2. aws kms list-resource-tags --region \$REGION --key-id \$KEY_ID --query 'Tags' --output json"

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
echo "Region         | Total KMS Keys "
echo "+--------------+-------------------+"

declare -A total_keys
declare -A non_compliant_keys

# Audit each region
for REGION in $regions; do
  keys=$(aws kms list-keys --region "$REGION" --profile "$PROFILE" --query 'Keys[*].KeyId' --output text)

  key_count=0
  non_compliant_list=()

  for KEY_ID in $keys; do
    ((key_count++))

    # Get KMS key tags
    tags=$(aws kms list-resource-tags --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --query 'Tags' --output json)

    if [[ "$tags" == "[]" ]]; then
      non_compliant_list+=("$KEY_ID (No Tags Assigned)")
    fi
  done

  total_keys["$REGION"]=$key_count
  non_compliant_keys["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-19s |\n" "$REGION" "$key_count"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_keys[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant KMS Keys:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_keys[@]}"; do
    if [[ -n "${non_compliant_keys[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Keys:"
      for key in ${non_compliant_keys[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All KMS keys have tags assigned.${NC}"
fi

echo "Audit completed for all regions."
