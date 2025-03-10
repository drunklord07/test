#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Endpoint Encryption"
criteria="This script checks if SageMaker endpoints are using Customer Managed Keys (CMK) for encryption."

# Commands used
command_used="Commands Used:
  1. aws sagemaker list-endpoints --region \$REGION --query 'Endpoints[*].EndpointName' --output text
  2. aws sagemaker describe-endpoint --region \$REGION --endpoint-name \$ENDPOINT_NAME --query 'EndpointConfigName' --output text
  3. aws sagemaker describe-endpoint-config --region \$REGION --endpoint-config-name \$CONFIG_NAME --query 'KmsKeyId' --output text"

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
echo "\n+----------------+----------------+"
echo "| Region         | Endpoint Count |"
echo "+----------------+----------------+"

declare -A endpoint_counts

# Gather SageMaker endpoint counts per region
for REGION in $regions; do
  endpoints=$(aws sagemaker list-endpoints --region "$REGION" --profile "$PROFILE" \
    --query 'Endpoints[*].EndpointName' --output text)

  endpoint_count=$(echo "$endpoints" | wc -w)
  endpoint_counts[$REGION]=$endpoint_count

  printf "| %-14s | %-14s |\n" "$REGION" "$endpoint_count"
done

echo "+----------------+----------------+"
echo ""

# Start audit for non-compliant SageMaker endpoints
non_compliant_found=false

for REGION in "${!endpoint_counts[@]}"; do
  if [ "${endpoint_counts[$REGION]}" -gt 0 ]; then
    endpoints=$(aws sagemaker list-endpoints --region "$REGION" --profile "$PROFILE" \
      --query 'Endpoints[*].EndpointName' --output text)

    for ENDPOINT_NAME in $endpoints; do
      CONFIG_NAME=$(aws sagemaker describe-endpoint --region "$REGION" --profile "$PROFILE" \
        --endpoint-name "$ENDPOINT_NAME" --query 'EndpointConfigName' --output text)

      KMS_KEY_ID=$(aws sagemaker describe-endpoint-config --region "$REGION" --profile "$PROFILE" \
        --endpoint-config-name "$CONFIG_NAME" --query 'KmsKeyId' --output text)

      if [ "$KMS_KEY_ID" == "null" ]; then
        if [ "$non_compliant_found" = false ]; then
          echo -e "${PURPLE}Starting audit for non-compliant SageMaker endpoints...${NC}"
          non_compliant_found=true
        fi

        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Endpoint Name: $ENDPOINT_NAME"
        echo "Endpoint Config: $CONFIG_NAME"
        echo "KMS Key ID: $KMS_KEY_ID"
        echo "Status: ${RED}Non-Compliant (Uses AWS-Managed Key Instead of CMK)${NC}"
        echo "--------------------------------------------------"
      fi
    done
  fi
done

if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker endpoints are using CMK for encryption.${NC}"
fi

echo "Audit completed for all regions."
