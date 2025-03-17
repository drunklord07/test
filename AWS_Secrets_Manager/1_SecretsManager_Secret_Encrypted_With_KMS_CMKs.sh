#!/bin/bash

# Description and Criteria
description="AWS Audit for Secrets Manager Encryption Compliance"
criteria="Identifies secrets encrypted with AWS-managed keys instead of customer-managed KMS CMKs."

# Commands used
command_used="Commands Used:
  1. aws secretsmanager list-secrets --region \$REGION --query 'SecretList[*].Name'
  2. aws secretsmanager describe-secret --region \$REGION --secret-id SECRET_NAME --query 'KmsKeyId'
  3. aws kms describe-key --region \$REGION --key-id KMS_KEY_ID --query 'KeyMetadata.KeyManager'"

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

# Step 2: Encryption Compliance Audit
echo -e "${PURPLE}Checking Secrets Manager Encryption Compliance...${NC}"
non_compliant_found=false

for REGION in "${!total_secrets[@]}"; do
    secrets=$(aws secretsmanager list-secrets --region "$REGION" --profile "$PROFILE" --query 'SecretList[*].Name' --output text 2>/dev/null)

    for secret in $secrets; do
        # Get KMS Key ID
        kms_key_id=$(aws secretsmanager describe-secret --region "$REGION" --profile "$PROFILE" --secret-id "$secret" --query 'KmsKeyId' --output text 2>/dev/null)

        if [[ -z "$kms_key_id" || "$kms_key_id" == "None" ]]; then
            continue  # Skip if KMS Key ID is missing (highly unlikely)
        fi

        # Check if Key Manager is AWS-managed or Customer-managed
        key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

        if [[ "$key_manager" == "AWS" ]]; then
            non_compliant_found=true
            echo -e "${RED}Region: $REGION${NC}"
            echo -e "${RED}Secret: $secret${NC}"
            echo -e "${RED}Status: NON-COMPLIANT (Uses AWS-managed key)${NC}"
            echo "----------------------------------------------------------------"
        fi
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All secrets are encrypted correctly.${NC}"
fi

echo "Audit completed for all regions."
