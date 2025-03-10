#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Models Without Network Isolation"
criteria="This script identifies Amazon SageMaker models that do not have Network Isolation enabled in each AWS region.
Models without this feature enabled are marked as 'Non-Compliant' (printed in red) as they may pose a security risk by allowing unrestricted network access."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws sagemaker list-models --region \$REGION --query 'Models[*].ModelName'
  3. aws sagemaker describe-model --region \$REGION --model-name \$MODEL --query 'EnableNetworkIsolation'"

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

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text)

# Flag to track compliance status
non_compliant_found=false

# Iterate through each AWS region
for REGION in $regions; do
  echo -e "${PURPLE}Checking region: $REGION${NC}"
  
  # Get the list of SageMaker models
  models=$(aws sagemaker list-models --region "$REGION" --query 'Models[*].ModelName' --output text)
  
  if [ -z "$models" ]; then
    echo "No models found in region $REGION."
    continue
  fi

  # Check each model for Network Isolation
  for MODEL in $models; do
    network_isolation_enabled=$(aws sagemaker describe-model --region "$REGION" --model-name "$MODEL" --query 'EnableNetworkIsolation' --output text)
    
    if [ "$network_isolation_enabled" == "False" ]; then
      non_compliant_found=true
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Model Name: $MODEL"
      echo -e "Status: ${RED}Non-Compliant (Network Isolation Not Enabled)${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

# Only print this message if no non-compliant models were found
if ! $non_compliant_found; then
  echo -e "${GREEN}All SageMaker models are compliant. Network Isolation is enabled.${NC}"
fi

echo "Audit completed for all regions."
