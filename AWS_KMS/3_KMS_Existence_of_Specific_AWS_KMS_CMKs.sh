#!/bin/bash

# Description and Criteria
description="AWS Audit for Existence of Specific AWS KMS Customer Master Keys (CMKs)"
criteria="This script checks if specific AWS KMS CMKs exist in the configured AWS regions by verifying their aliases."

# Commands used
command_used="Commands Used:
  1. aws kms list-aliases --region \$REGION --query 'Aliases[*].AliasName' --output text"

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

# Define the required KMS aliases
required_aliases=(
  "alias/cc-protected-key"
  "alias/cc-internal-key"
  "alias/cc-prod-manager-key"
)

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Required CMKs Found "
echo "+--------------+-------------------+"

declare -A region_compliance

# Audit each region
for REGION in $regions; do
  aliases=$(aws kms list-aliases --region "$REGION" --profile "$PROFILE" --query 'Aliases[*].AliasName' --output text)

  found_count=0
  missing_aliases=()

  for alias in "${required_aliases[@]}"; do
    if echo "$aliases" | grep -q "$alias"; then
      ((found_count++))
    else
      missing_aliases+=("$alias")
    fi
  done

  region_compliance["$REGION"]="${missing_aliases[@]}"

  printf "| %-14s | %-19s |\n" "$REGION" "$found_count/${#required_aliases[@]}"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
if [ ${#region_compliance[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_compliance[@]}"; do
    if [[ -n "${region_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Missing CMKs:"
      for alias in ${region_compliance[$region]}; do
        echo " - $alias"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS regions have the required CMKs.${NC}"
fi

echo "Audit completed for all regions."
