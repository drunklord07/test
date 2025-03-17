#!/bin/bash

# Description and Criteria
description="AWS Audit for KMS Customer Master Keys (CMKs) with Overly Permissive Policies"
criteria="This script verifies if any KMS CMKs have overly permissive key policies where the Principal is set to '*' without restrictive conditions."

# Commands used
command_used="Commands Used:
  1. aws kms list-keys --region \$REGION --no-paginate --query 'Keys[*].KeyId' --output json
  2. aws kms get-key-policy --region \$REGION --key-id \$KEY_ID --policy-name default --query 'Policy' --output json"

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
declare -A region_compliant

# Audit each region
for REGION in $regions; do
  # Get all KMS keys as a JSON array and count them correctly
  key_ids=$(aws kms list-keys --region "$REGION" --profile "$PROFILE" --no-paginate --query 'Keys[*].KeyId' --output json)
  checked_count=$(echo "$key_ids" | grep -o 'KeyId' | wc -l)

  non_compliant_keys=()
  compliant_keys=()

  # Loop through each key ID
  for KEY_ID in $(echo "$key_ids" | tr -d '[]" ,' | sed '/^$/d'); do
    # Get KMS Key Policy
    key_policy=$(aws kms get-key-policy --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --policy-name default --query 'Policy' --output json 2>/dev/null)

    # Check if policy is overly permissive
    if [[ "$key_policy" == *'"Principal": "*"'* || "$key_policy" == *'"AWS": "*"'* ]]; then
      if [[ "$key_policy" != *'"Condition"'* ]]; then
        non_compliant_keys+=("$KEY_ID")
      else
        compliant_keys+=("$KEY_ID")
      fi
    else
      compliant_keys+=("$KEY_ID")
    fi
  done

  region_compliance["$REGION"]="${non_compliant_keys[@]}"
  region_compliant["$REGION"]="${compliant_keys[@]}"

  printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
non_compliant_found=false

for region in "${!region_compliance[@]}"; do
  if [[ -n "${region_compliance[$region]}" ]]; then
    non_compliant_found=true
    break
  fi
done

if $non_compliant_found; then
  echo -e "${PURPLE}Non-Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_compliance[@]}"; do
    if [[ -n "${region_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant KMS Keys:"
      for key in ${region_compliance[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS regions have compliant KMS key policies.${NC}"
fi

# Compliant Keys Section
echo -e "${GREEN}Compliant AWS Regions:${NC}"
echo "----------------------------------------------------------------"

for region in "${!region_compliant[@]}"; do
  if [[ -n "${region_compliant[$region]}" ]]; then
    echo -e "${GREEN}Region: $region${NC}"
    echo "Compliant KMS Keys:"
    for key in ${region_compliant[$region]}; do
      echo " - $key"
    done
    echo "----------------------------------------------------------------"
  fi
done

echo "Audit completed for all regions."
