#!/bin/bash

# Description and Criteria
description="AWS Audit for KMS Customer Managed Keys (CMKs) with Automatic Key Rotation Disabled"
criteria="This script verifies if symmetric Customer Managed KMS keys (CMKs) have automatic key rotation enabled."

# Commands used
command_used="Commands Used:
  1. aws kms list-keys --region \$REGION --query 'Keys[*].KeyId'
  2. aws kms describe-key --region \$REGION --key-id \$KEY_ID --query 'KeyMetadata.{KeyManager: KeyManager, KeySpec: KeySpec}'
  3. aws kms get-key-rotation-status --region \$REGION --key-id \$KEY_ID --query 'KeyRotationEnabled'"

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
  non_compliant_keys=()

  for KEY_ID in $key_ids; do
    checked_count=$((checked_count + 1))

    # Get KMS Key Metadata
    key_metadata=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --query 'KeyMetadata.{KeyManager: KeyManager, KeySpec: KeySpec}' --output json 2>/dev/null)

    key_manager=$(echo "$key_metadata" | jq -r '.KeyManager')
    key_spec=$(echo "$key_metadata" | jq -r '.KeySpec')

    # Check if key is a customer-managed symmetric CMK
    if [[ "$key_manager" == "CUSTOMER" && "$key_spec" == "SYMMETRIC_DEFAULT" ]]; then
      # Get Key Rotation Status
      key_rotation_enabled=$(aws kms get-key-rotation-status --region "$REGION" --profile "$PROFILE" --key-id "$KEY_ID" --query 'KeyRotationEnabled' --output text 2>/dev/null)

      if [[ "$key_rotation_enabled" == "false" ]]; then
        non_compliant_keys+=("$KEY_ID")
      fi
    fi
  done

  region_compliance["$REGION"]="${non_compliant_keys[@]}"

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
      echo "Non-Compliant KMS Keys (Rotation Disabled):"
      for key in ${region_compliance[$region]}; do
        echo " - $key"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS regions have automatic key rotation enabled for Customer Managed CMKs.${NC}"
fi

echo "Audit completed for all regions."
