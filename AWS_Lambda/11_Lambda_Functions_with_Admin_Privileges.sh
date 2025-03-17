#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Execution Roles (Admin Privileges Check)"
criteria="This script checks if AWS Lambda execution roles have admin privileges (Action: * and Effect: Allow)."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function --region \$REGION --function-name \$FUNCTION --query 'Configuration.Role'
  3. aws iam list-attached-role-policies --role-name \$ROLE_NAME --query 'AttachedPolicies[*].PolicyArn'
  4. aws iam get-policy-version --policy-arn \$POLICY_ARN --version-id \$VERSION_ID --query 'PolicyVersion.Document'
  5. aws iam list-role-policies --role-name \$ROLE_NAME --query 'PolicyNames'
  6. aws iam get-role-policy --role-name \$ROLE_NAME --policy-name \$POLICY_NAME --query 'PolicyDocument'"

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

    # Get Managed Policies Attached to Role
    policy_arns=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyArn' --output text)

    # Check Managed Policies for Admin Privileges
    for POLICY_ARN in $policy_arns; do
      policy_version_id=$(aws iam get-policy --policy-arn "$POLICY_ARN" --profile "$PROFILE" --query 'Policy.DefaultVersionId' --output text)
      policy_doc=$(aws iam get-policy-version --policy-arn "$POLICY_ARN" --version-id "$policy_version_id" --profile "$PROFILE" --query 'PolicyVersion.Document' --output json)

      if echo "$policy_doc" | grep -q '"Action": "*"' && echo "$policy_doc" | grep -q '"Effect": "Allow"'; then
        non_compliant_list+=("$FUNCTION")
        break  # No need to check further policies
      fi
    done

    # Get Inline Policies
    inline_policies=$(aws iam list-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'PolicyNames' --output text)

    # Check Inline Policies for Admin Privileges
    for POLICY_NAME in $inline_policies; do
      policy_doc=$(aws iam get-role-policy --role-name "$role_name" --policy-name "$POLICY_NAME" --profile "$PROFILE" --query 'PolicyDocument' --output json)

      if echo "$policy_doc" | grep -q '"Action": "*"' && echo "$policy_doc" | grep -q '"Effect": "Allow"'; then
        non_compliant_list+=("$FUNCTION")
        break  # No need to check further policies
      fi
    done
  done

  total_functions["$REGION"]=$checked_count
  non_compliant_functions["$REGION"]="${non_compliant_list[*]}"
  
  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
if [ ${#non_compliant_functions[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Lambda Functions (Admin Privileges Detected):${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_functions[@]}"; do
    if [[ -n "${non_compliant_functions[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Lambda Functions:"
      echo -e "${RED}${non_compliant_functions[$region]}${NC}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS Lambda functions follow the principle of least privilege.${NC}"
fi

echo "Audit completed for all regions."
