#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Training Job Encryption"
criteria="This script checks if SageMaker training jobs are using Customer Managed Keys (CMK) for encryption."

# Commands used
command_used="Commands Used:
  1. aws sagemaker list-training-jobs --region \$REGION --query 'TrainingJobSummaries[*].TrainingJobName' --output text
  2. aws sagemaker describe-training-job --region \$REGION --training-job-name \$JOB_NAME --query '{\"OutputKmsKey\":OutputDataConfig.KmsKeyId,\"VolumeKmsKey\":ResourceConfig.VolumeKmsKeyId}' --output json"

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
echo "| Region         | Job Count      |"
echo "+----------------+----------------+"

declare -A job_counts

# Gather SageMaker training job counts per region
for REGION in $regions; do
  jobs=$(aws sagemaker list-training-jobs --region "$REGION" --profile "$PROFILE" \
    --query 'TrainingJobSummaries[*].TrainingJobName' --output text)

  job_count=$(echo "$jobs" | wc -w)
  job_counts[$REGION]=$job_count

  printf "| %-14s | %-14s |\n" "$REGION" "$job_count"
done

echo "+----------------+----------------+"
echo ""

# Start audit for non-compliant SageMaker training jobs
non_compliant_found=false

for REGION in "${!job_counts[@]}"; do
  if [ "${job_counts[$REGION]}" -gt 0 ]; then
    jobs=$(aws sagemaker list-training-jobs --region "$REGION" --profile "$PROFILE" \
      --query 'TrainingJobSummaries[*].TrainingJobName' --output text)

    for JOB_NAME in $jobs; do
      encryption_info=$(aws sagemaker describe-training-job --region "$REGION" --profile "$PROFILE" \
        --training-job-name "$JOB_NAME" --query '{"OutputKmsKey":OutputDataConfig.KmsKeyId,"VolumeKmsKey":ResourceConfig.VolumeKmsKeyId}' --output json)

      volume_kms=$(echo "$encryption_info" | jq -r '.VolumeKmsKey')
      output_kms=$(echo "$encryption_info" | jq -r '.OutputKmsKey')

      if [ "$volume_kms" == "null" ] || [ -z "$output_kms" ]; then
        if [ "$non_compliant_found" = false ]; then
          echo -e "${PURPLE}Starting audit for non-compliant SageMaker training jobs...${NC}"
          non_compliant_found=true
        fi

        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Training Job Name: $JOB_NAME"
        echo "Volume KMS Key: $volume_kms"
        echo "Output KMS Key: $output_kms"

        if [ "$volume_kms" == "null" ]; then
          echo "Status: ${RED}Non-Compliant (Training Volume Uses AWS-Managed Key Instead of CMK)${NC}"
        fi

        if [ -z "$output_kms" ]; then
          echo "Status: ${RED}Non-Compliant (Training Job Output Uses AWS-Managed Key Instead of CMK)${NC}"
        fi

        echo "--------------------------------------------------"
      fi
    done
  fi
done

if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker training jobs are using CMK for encryption.${NC}"
fi

echo "Audit completed for all regions."
