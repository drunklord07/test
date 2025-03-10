#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Notebook Instance IAM Role Compliance"
criteria="This script verifies whether Amazon SageMaker notebook instances have valid IAM execution roles. Instances with missing or deleted roles are considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws sagemaker list-notebook-instances --region \$REGION --query 'NotebookInstances[*].NotebookInstanceName'
  3. aws sagemaker describe-notebook-instance --region \$REGION --notebook-instance-name \$INSTANCE --query 'RoleArn'
  4. aws iam get-role --role-name \$ROLE_NAME"

# Display script metadata
echo ""
echo "---------------------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
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
echo "+----------------+----------------------+"
echo "| Region         | Notebook Instances   |"
echo "+----------------+----------------------+"

# Collect notebook count per region
declare -A region_instance_count
total_instances=0

for REGION in $regions; do
  instances=$(aws sagemaker list-notebook-instances --region "$REGION" --profile "$PROFILE" \
    --query 'NotebookInstances[*].NotebookInstanceName' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count["$REGION"]=$instance_count
  total_instances=$((total_instances + instance_count))

  printf "| %-14s | %-20s |\n" "$REGION" "$instance_count"
done

echo "+----------------+----------------------+"
echo ""

# Perform IAM role compliance audit
non_compliant_found=false
if [[ "$total_instances" -eq 0 ]]; then
  echo "No SageMaker notebook instances found across all regions."
  exit 0
fi

echo "Starting SageMaker IAM role compliance audit..."

for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  instances=$(aws sagemaker list-notebook-instances --region "$REGION" --profile "$PROFILE" \
    --query 'NotebookInstances[*].NotebookInstanceName' --output text)

  for INSTANCE in $instances; do
    role_arn=$(aws sagemaker describe-notebook-instance --region "$REGION" --profile "$PROFILE" \
      --notebook-instance-name "$INSTANCE" --query 'RoleArn' --output text)

    if [[ "$role_arn" == "None" || -z "$role_arn" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Notebook Instance: $INSTANCE"
      echo "IAM Role: None"
      echo -e "\033[0;31mStatus: NON-COMPLIANT (No IAM role assigned)\033[0m"
      echo "Action: Assign a valid IAM execution role to the instance."
      echo "--------------------------------------------------"
      non_compliant_found=true
      continue
    fi

    role_name=$(echo "$role_arn" | awk -F'/' '{print $2}')

    # Check if the role exists
    if ! aws iam get-role --role-name "$role_name" --profile "$PROFILE" > /dev/null 2>&1; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Notebook Instance: $INSTANCE"
      echo "IAM Role: $role_name"
      echo -e "\033[0;31mStatus: NON-COMPLIANT (IAM role not found)\033[0m"
      echo "Action: Reassign a valid IAM execution role to the instance."
      echo "--------------------------------------------------"
      non_compliant_found=true
    fi
  done
done

# Display compliance message only if all instances are valid
if [ "$non_compliant_found" = false ]; then
  echo -e "\033[0;32mAll SageMaker notebook instances have valid IAM execution roles.\033[0m"
fi

echo "Audit completed for all regions."
