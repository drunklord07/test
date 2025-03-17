#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Execution Roles Using Customer-Managed & Inline Policies"
criteria="This script checks if AWS Lambda execution roles use only AWS-managed policies and have no inline policies."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function --region \$REGION --function-name \$FUNCTION --query 'Configuration.Role'
  3. aws iam list-attached-role-policies --role-name \$ROLE_NAME --query 'AttachedPolicies[*].PolicyArn'
  4. aws iam list-role-policies --role-name \$ROLE_NAME --query 'PolicyNames'"

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
echo "Region         | Lambda Functions"
echo "+--------------+----------------+"

declare -A total_functions
declare -A customer_managed
declare -A inline_policies

# Audit each region
for REGION in $regions; do
  function_names=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query 'Functions[*].FunctionName' --output text)

  checked_count=0

  for FUNCTION in $function_names; do
    checked_count=$((checked_count + 1))

    # Get Lambda Execution Role ARN
    role_arn=$(aws lambda get-function --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'Configuration.Role' --output text)
    role_name=$(basename "$role_arn")  # Extract role name from ARN

    # Check Managed Policies
    policy_arns=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyArn' --output text)

    for policy_arn in $policy_arns; do
      if [[ "$policy_arn" =~ arn:aws:iam::[0-9]+:policy/ ]]; then
        customer_managed["$FUNCTION"]="true"
      fi
    done

    # Check Inline Policies
    inline_policies_list=$(aws iam list-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'PolicyNames' --output text)
    
    if [[ -n "$inline_policies_list" ]]; then
      inline_policies["$FUNCTION"]="true"
    fi
  done

  total_functions["$REGION"]=$checked_count
  
  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
customer_managed_found=false
inline_policies_found=false

for function in "${!customer_managed[@]}"; do
  customer_managed_found=true
  echo -e "${RED}Customer-Managed Policy Detected: $function${NC}"
  echo "This Lambda function uses a customer-managed IAM policy instead of an AWS-managed one."
  echo "----------------------------------------------------------------"
done

for function in "${!inline_policies[@]}"; do
  inline_policies_found=true
  echo -e "${RED}Inline Policy Detected: $function${NC}"
  echo "This Lambda function has an inline policy attached to its execution role."
  echo "----------------------------------------------------------------"
done

if ! $customer_managed_found; then
  echo -e "${GREEN}All AWS Lambda functions use only AWS-managed policies.${NC}"
fi

if ! $inline_policies_found; then
  echo -e "${GREEN}No Lambda execution roles have inline policies.${NC}"
fi

echo "Audit completed for all regions."
