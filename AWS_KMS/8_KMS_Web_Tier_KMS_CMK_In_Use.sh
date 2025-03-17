#!/bin/bash

# Description and Criteria
description="AWS Audit for KMS Customer Managed Keys (CMKs) in Use - Checking for Tags"
criteria="This script checks all active KMS CMKs in use across AWS regions and verifies if they have tags defined."

# Commands used
command_used="Commands Used:
  1. aws kms list-keys --region \$REGION --query 'Keys[*].KeyId'
  2. aws kms list-resource-tags --region \$REGION --key-id \$KEY_ID --query 'Tags'"

# Color codes
GREEN='\033[0;32m'
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
echo "Region         | Total CMKs Checked"
echo "+--------------+-------------------+"

declare -A region_compliance

# Audit each region
for REGION in $regions; do
  key_ids=$(aws kms list-keys --region "$REGION" --profile "$PROFILE" --query 'Keys[*].KeyId' --output text)

  checked_count=0
  untagged_keys=()

  for KEY_ID in $key_ids; do
    checked_count=$((checked_count + 1))

    # Get KMS Key Tags
    key_tags=$(aws kms list-resource-tags --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --query 'Tags' --output json 2>/dev/null)

    if [[ "$key_tags" == "[]" ]]; then
      untagged_keys+=("$KEY_ID")
    fi
  done

  region_compliance["$REGION"]="${untagged_keys[@]}"

  printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
untagged_found=false

for region in "${!region_compliance[@]}"; do
  if [[ -n "${region_compliance[$region]}" ]]; then
    untagged_found=true
    break
  fi
done

if $untagged_found; then
  echo -e "${PURPLE}Non-Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_compliance[@]}"; do
    if [[ -n "${region_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "KMS Keys Without Tags:"
      for key in ${region_compliance[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS KMS CMKs have tags assigned.${NC}"
fi

echo "Audit completed for all regions."
