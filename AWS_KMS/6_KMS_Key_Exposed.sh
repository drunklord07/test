#!/bin/bash

# Description and Criteria
description="AWS Audit for KMS Customer Master Keys (CMKs) with Overly Permissive Policies"
criteria="This script verifies if any KMS CMKs have overly permissive key policies where the Principal is set to '*' without restrictive conditions."

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

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Total CMKs Checked"
echo "+--------------+-------------------+"

declare -A region_compliance
declare -A region_non_compliance

# Audit each region
for REGION in $regions; do
  # Fetch all CMK IDs
  key_ids=$(aws kms list-keys --region "$REGION" --profile "$PROFILE" --query 'Keys[*].KeyId' --output text)

  # Skip region if no CMKs exist
  if [[ -z "$key_ids" ]]; then
    printf "| %-14s | %-18s |\n" "$REGION" "0"
    continue
  fi

  checked_count=0
  compliant_keys=()
  non_compliant_keys=()

  for KEY_ID in $key_ids; do
    checked_count=$((checked_count + 1))

    # Get KMS Key Policy
    key_policy=$(aws kms get-key-policy --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --policy-name default --query 'Policy' --output text 2>/dev/null)

    # Skip if policy retrieval fails
    if [[ -z "$key_policy" ]]; then
      continue
    fi

    # Check for overly permissive policies
    if echo "$key_policy" | grep -q '"Principal": "*"' || echo "$key_policy" | grep -q '"AWS": "*"'; then
      if ! echo "$key_policy" | grep -q '"Condition"'; then
        non_compliant_keys+=("$KEY_ID")
        continue
      fi
    fi

    # If not non-compliant, mark as compliant
    compliant_keys+=("$KEY_ID")
  done

  region_non_compliance["$REGION"]="${non_compliant_keys[@]}"
  region_compliance["$REGION"]="${compliant_keys[@]}"

  printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
non_compliant_found=false
compliant_found=false

for region in "${!region_non_compliance[@]}"; do
  if [[ -n "${region_non_compliance[$region]}" ]]; then
    non_compliant_found=true
    break
  fi
done

for region in "${!region_compliance[@]}"; do
  if [[ -n "${region_compliance[$region]}" ]]; then
    compliant_found=true
    break
  fi
done

if $non_compliant_found; then
  echo -e "${RED}Non-Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_non_compliance[@]}"; do
    if [[ -n "${region_non_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant KMS Keys:"
      for key in ${region_non_compliance[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}No non-compliant KMS keys found in any region.${NC}"
fi

echo ""

if $compliant_found; then
  echo -e "${GREEN}Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_compliance[@]}"; do
    if [[ -n "${region_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Compliant KMS Keys:"
      for key in ${region_compliance[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${RED}No compliant KMS keys found.${NC}"
fi

echo "Audit completed for all regions."
