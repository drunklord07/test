#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Training Jobs Without Inter-Container Traffic Encryption"
criteria="This script identifies Amazon SageMaker training jobs that do not have inter-container traffic encryption enabled in each AWS region.
Training jobs without this feature enabled are marked as 'Non-Compliant' (printed in red) as they may be vulnerable to data interception risks."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws sagemaker list-training-jobs --region \$REGION --query 'TrainingJobSummaries[*].TrainingJobName'
  3. aws sagemaker describe-training-job --region \$REGION --training-job-name \$TRAINING_JOB --query 'EnableInterContainerTrafficEncryption'"

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

# Track non-compliant instances
non_compliant_found=false

# Iterate through each AWS region
for REGION in $regions; do
  echo -e "${PURPLE}Checking region: $REGION${NC}"
  
  # Get the list of training jobs
  training_jobs=$(aws sagemaker list-training-jobs --region "$REGION" --query 'TrainingJobSummaries[*].TrainingJobName' --output text)
  
  if [ -z "$training_jobs" ]; then
    echo "No training jobs found in region $REGION."
    continue
  fi

  # Check each training job for inter-container traffic encryption
  for TRAINING_JOB in $training_jobs; do
    encryption_enabled=$(aws sagemaker describe-training-job --region "$REGION" --training-job-name "$TRAINING_JOB" --query 'EnableInterContainerTrafficEncryption' --output text)
    
    if [ "$encryption_enabled" == "False" ]; then
      non_compliant_found=true
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Training Job: $TRAINING_JOB"
      echo -e "Status: ${RED}Non-Compliant (Inter-Container Traffic Encryption Not Enabled)${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

# If no non-compliant instances found, print a message
if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker training jobs are compliant. Inter-container traffic encryption is enabled.${NC}"
fi

echo "Audit completed for all regions."
