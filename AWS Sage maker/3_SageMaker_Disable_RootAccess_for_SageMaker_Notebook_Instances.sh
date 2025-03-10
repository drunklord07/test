#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Notebook Instances with Root Access Enabled"
criteria="This script identifies Amazon SageMaker notebook instances that have root access enabled in each AWS region.
Instances with root access enabled are marked as 'Non-Compliant' (printed in red) as they pose security risks."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws sagemaker list-notebook-instances --region \$REGION --query 'NotebookInstances[*].NotebookInstanceName'
  3. aws sagemaker describe-notebook-instance --region \$REGION --notebook-instance-name \$INSTANCE --query 'RootAccess'"

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

# Set AWS CLI profile (change this as needed)
PROFILE="my-role"

# Validate if the AWS profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

non_compliant_found=false

# Iterate through each region
for REGION in $regions; do
  instances=$(aws sagemaker list-notebook-instances --region "$REGION" --profile "$PROFILE" \
    --query 'NotebookInstances[*].NotebookInstanceName' --output text)

  for INSTANCE in $instances; do
    root_access=$(aws sagemaker describe-notebook-instance --region "$REGION" --profile "$PROFILE" \
      --notebook-instance-name "$INSTANCE" --query 'RootAccess' --output text)

    if [[ "$root_access" == "Enabled" ]]; then
      non_compliant_found=true
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Notebook Instance: $INSTANCE"
      echo -e "Status: ${RED}Non-Compliant (Root Access Enabled)${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

# Message if all instances are compliant
if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker notebook instances are compliant. No root access enabled.${NC}"
fi

echo "Audit completed for all regions."
