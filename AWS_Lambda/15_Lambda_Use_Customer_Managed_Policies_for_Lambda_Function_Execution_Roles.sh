#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Execution Roles (Fine-Grained Access Control Check)"
criteria="This script checks if AWS Lambda execution roles are configured with customer-managed policies."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function --region \$REGION --function-name \$FUNCTION --query 'Configuration.Role'
  3. aws iam list-attached-role-policies --role-name \$ROLE_NAME --query 'AttachedPolicies[*].PolicyArn'"

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
declare -A non_compliant_functions

# Audit each region
for REGION in $regions; do
  function_names=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query 'Functions[*].FunctionName' --output text)

  checked_count=0
  non_compliant_list=()

  for FUNCTION in $function_names; do
    checked_count=$((checked_count + 1))

    # Get Lambda Execution Role ARN
    role_arn=$(aws lambda get-function --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'Configuration.Role' --output text)
    role_name=$(basename "$role_arn")  # Extract role name from ARN

    # Get Attached Managed Policies
    managed_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyArn' --output text)

    # Check for customer-managed policies
    if ! echo "$managed_policies" | grep -q "arn:aws:iam::[0-9]*:policy/"; then
      non_compliant_list+=("$FUNCTION")
    fi
  done

  total_functions["$REGION"]=$checked_count
  non_compliant_functions["$REGION"]="${non_compliant_list[*]}"
  
  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
if [ ${#non_compliant_functions[@]} -gt 0 ]; then
  echo -e "${RED}Lambda Functions Without Customer-Managed Policies:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_functions[@]}"; do
    if [[ -n "${non_compliant_functions[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Lambda Functions Without Customer-Managed Policies:"
      echo -e "${RED}${non_compliant_functions[$region]}${NC}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS Lambda functions follow best practices (Using Customer-Managed Policies).${NC}"
fi

echo "Audit completed for all regions."
