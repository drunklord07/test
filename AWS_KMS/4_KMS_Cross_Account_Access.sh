#!/bin/bash

# Description and Criteria
description="AWS Audit for KMS CMK Cross-Account Access"
criteria="This script checks the key policies of AWS KMS CMKs to identify cross-account access."

# Commands used
command_used="Commands Used:
  1. aws kms list-keys --region \$REGION --query 'Keys[*].KeyId' --output text
  2. aws kms get-key-policy --region \$REGION --key-id \$KEY_ID --policy-name default --query 'Policy' --output text"

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

# Define trusted AWS account IDs
trusted_accounts=(
  "arn:aws:iam::123456789012:root"
  "arn:aws:iam::111122223333:root"
)

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | CMKs Checked | Non-Compliant CMKs "
echo "+--------------+-------------+-------------------+"

declare -A region_compliance

# Audit each region
for REGION in $regions; do
  key_ids=$(aws kms list-keys --region "$REGION" --profile "$PROFILE" --query 'Keys[*].KeyId' --output text)

  checked_count=0
  non_compliant_count=0
  non_compliant_keys=()

  for KEY_ID in $key_ids; do
    checked_count=$((checked_count + 1))

    # Get key policy
    policy=$(aws kms get-key-policy --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --policy-name default --output text 2>/dev/null)

    if [[ -z "$policy" ]]; then
      continue
    fi

    # Extract AWS Principals from the policy
    principals=$(echo "$policy" | grep -oE '"AWS": ?"arn:aws:iam::[0-9]+:root"' | awk -F'"' '{print $4}')

    # Check for non-trusted accounts
    for principal in $principals; do
      if [[ ! " ${trusted_accounts[*]} " =~ " $principal " ]]; then
        non_compliant_keys+=("$KEY_ID")
        non_compliant_count=$((non_compliant_count + 1))
        break
      fi
    done
  done

  region_compliance["$REGION"]="${non_compliant_keys[@]}"

  printf "| %-14s | %-11s | %-17s |\n" "$REGION" "$checked_count" "$non_compliant_count"
done

echo "+--------------+-------------+-------------------+"
echo ""

# Audit Section
if [ ${#region_compliance[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_compliance[@]}"; do
    if [[ -n "${region_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant CMKs:"
      for key in ${region_compliance[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS regions have compliant KMS CMKs.${NC}"
fi

echo "Audit completed for all regions."
