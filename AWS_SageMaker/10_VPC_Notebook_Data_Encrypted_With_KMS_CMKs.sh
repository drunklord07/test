#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Notebook Instance Encryption"
criteria="This script checks if SageMaker notebook instances are using Customer Managed Keys (CMK) for encryption."

# Commands used
command_used="Commands Used:
  1. aws sagemaker list-notebook-instances --region \$REGION --query 'NotebookInstances[*].NotebookInstanceName' --output text
  2. aws sagemaker describe-notebook-instance --region \$REGION --notebook-instance-name \$INSTANCE_NAME --query 'KmsKeyId' --output text"

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
echo "| Region         | Instance Count |"
echo "+----------------+----------------+"

declare -A instance_counts

# Gather SageMaker notebook instance counts per region
for REGION in $regions; do
  instances=$(aws sagemaker list-notebook-instances --region "$REGION" --profile "$PROFILE" \
    --query 'NotebookInstances[*].NotebookInstanceName' --output text)

  instance_count=$(echo "$instances" | wc -w)
  instance_counts[$REGION]=$instance_count

  printf "| %-14s | %-14s |\n" "$REGION" "$instance_count"
done

echo "+----------------+----------------+"
echo ""

# Start audit for non-compliant SageMaker notebook instances
non_compliant_found=false

for REGION in "${!instance_counts[@]}"; do
  if [ "${instance_counts[$REGION]}" -gt 0 ]; then
    instances=$(aws sagemaker list-notebook-instances --region "$REGION" --profile "$PROFILE" \
      --query 'NotebookInstances[*].NotebookInstanceName' --output text)

    for INSTANCE_NAME in $instances; do
      KMS_KEY_ID=$(aws sagemaker describe-notebook-instance --region "$REGION" --profile "$PROFILE" \
        --notebook-instance-name "$INSTANCE_NAME" --query 'KmsKeyId' --output text)

      if [ "$KMS_KEY_ID" == "null" ]; then
        if [ "$non_compliant_found" = false ]; then
          echo -e "${PURPLE}Starting audit for non-compliant SageMaker notebook instances...${NC}"
          non_compliant_found=true
        fi

        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Notebook Instance Name: $INSTANCE_NAME"
        echo "KMS Key ID: $KMS_KEY_ID"
        echo "Status: ${RED}Non-Compliant (Uses AWS-Managed Key Instead of CMK)${NC}"
        echo "--------------------------------------------------"
      fi
    done
  fi
done

if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker notebook instances are using CMK for encryption.${NC}"
fi

echo "Audit completed for all regions."
