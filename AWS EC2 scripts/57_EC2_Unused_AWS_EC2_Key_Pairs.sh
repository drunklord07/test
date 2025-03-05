#!/bin/bash

# Description and Criteria
description="AWS Audit for Unused EC2 SSH Key Pairs"
criteria="This script checks if any EC2 key pairs exist that are not associated with any instances, indicating they may be unused and should be removed."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-key-pairs --region \$REGION --query 'KeyPairs[*].KeyName' --output text
  3. aws ec2 describe-instances --region \$REGION --filters Name=key-name,Values=\$KEY_NAME --query 'Reservations[*].Instances[*].InstanceId[]' --output text"

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
echo "Region         | Unused SSH Key Pairs"
echo "+--------------+----------------------------------+"

# Dictionary to store unused key pairs
declare -A unused_keys

# Audit each region
for REGION in $regions; do
  # Get all key pairs
  key_names=$(aws ec2 describe-key-pairs --region "$REGION" --profile "$PROFILE" \
    --query 'KeyPairs[*].KeyName' --output text)

  if [[ -z "$key_names" ]]; then
    printf "| %-14s | ${GREEN}No key pairs found${NC}            |\n" "$REGION"
    continue
  fi

  unused_keys_in_region=()
  for KEY_NAME in $key_names; do
    # Check if the key is associated with any EC2 instance
    instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --filters Name=key-name,Values="$KEY_NAME" \
      --query 'Reservations[*].Instances[*].InstanceId[]' --output text)

    if [[ -z "$instance_ids" ]]; then
      unused_keys_in_region+=("$KEY_NAME")
    fi
  done

  if [[ ${#unused_keys_in_region[@]} -gt 0 ]]; then
    unused_keys["$REGION"]="${unused_keys_in_region[*]}"
    printf "| %-14s | ${RED}%-30s${NC} |\n" "$REGION" "$(echo "${unused_keys_in_region[*]}" | wc -w) Unused Key(s)"
  else
    printf "| %-14s | ${GREEN}All keys in use${NC}               |\n" "$REGION"
  fi
done

echo "+--------------+----------------------------------+"
echo ""

# Audit Section
if [ ${#unused_keys[@]} -gt 0 ]; then
  echo -e "${RED}Unused SSH Key Pairs:${NC}"
  echo "---------------------------------------------------"

  for region in "${!unused_keys[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Unused Key Pairs:"
    echo -e "${unused_keys[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No unused SSH key pairs detected.${NC}"
fi

echo "Audit completed for all regions."
