#!/bin/bash

# Description and Criteria
description="AWS Audit for Secrets Manager Usage"
criteria="Checks if AWS Secrets Manager is in use by verifying if secrets exist in each region."

# Commands used
command_used="Commands Used:
  1. aws secretsmanager list-secrets --region \$REGION --query 'SecretList[*].Name'"

# Color codes
RED='\033[0;31m'
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

# Table Header (Instant Display)
echo "Region         | Total Secrets"
echo "+--------------+----------------+"

declare -A total_secrets
total_secrets_found=false

# Step 1: Quickly gather total secrets per region and display the table
for REGION in $regions; do
    secrets_count=$(aws secretsmanager list-secrets --region "$REGION" --profile "$PROFILE" --query 'SecretList[*].Name' --output text 2>/dev/null | wc -w)
    total_secrets["$REGION"]=$secrets_count

    if [[ "$secrets_count" -gt 0 ]]; then
        total_secrets_found=true
    fi

    printf "| %-14s | %-14s |\n" "$REGION" "$secrets_count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Final Compliance Check
if [[ "$total_secrets_found" == false ]]; then
    echo -e "${GREEN}AWS Secrets Manager is not in use in this AWS account.${NC}"
else
    echo -e "${PURPLE}AWS Secrets Manager is being used in some regions.${NC}"
fi

echo "Audit completed for all regions."
