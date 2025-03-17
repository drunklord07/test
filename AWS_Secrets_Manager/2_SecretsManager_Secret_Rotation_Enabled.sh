#!/bin/bash

# Description and Criteria
description="AWS Audit for Secrets Manager Automatic Rotation Compliance"
criteria="Identifies secrets that do not have automatic rotation enabled."

# Commands used
command_used="Commands Used:
  1. aws secretsmanager list-secrets --region \$REGION --query 'SecretList[*].Name'
  2. aws secretsmanager describe-secret --region \$REGION --secret-id SECRET_NAME --query 'RotationEnabled'"

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

# Step 1: Quickly gather total secrets per region and display the table
for REGION in $regions; do
    secrets_count=$(aws secretsmanager list-secrets --region "$REGION" --profile "$PROFILE" --query 'SecretList[*].Name' --output text 2>/dev/null | wc -w)
    total_secrets["$REGION"]=$secrets_count
    printf "| %-14s | %-14s |\n" "$REGION" "$secrets_count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Rotation Compliance Audit
echo -e "${PURPLE}Checking Secrets Manager Rotation Compliance...${NC}"
non_compliant_found=false

for REGION in "${!total_secrets[@]}"; do
    secrets=$(aws secretsmanager list-secrets --region "$REGION" --profile "$PROFILE" --query 'SecretList[*].Name' --output text 2>/dev/null)

    for secret in $secrets; do
        # Get Rotation Status
        rotation_enabled=$(aws secretsmanager describe-secret --region "$REGION" --profile "$PROFILE" --secret-id "$secret" --query 'RotationEnabled' --output text 2>/dev/null)

        if [[ "$rotation_enabled" == "False" ]]; then
            non_compliant_found=true
            echo -e "${RED}Region: $REGION${NC}"
            echo -e "${RED}Secret: $secret${NC}"
            echo -e "${RED}Status: NON-COMPLIANT (Rotation Disabled)${NC}"
            echo "----------------------------------------------------------------"
        fi
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All secrets have automatic rotation enabled.${NC}"
fi

echo "Audit completed for all regions."
