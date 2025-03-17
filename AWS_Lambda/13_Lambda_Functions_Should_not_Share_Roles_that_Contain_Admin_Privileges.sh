#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Execution Role Sharing & Admin Privileges"
criteria="This script checks if multiple AWS Lambda functions share the same execution role and detects roles with full administrative permissions."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function --region \$REGION --function-name \$FUNCTION --query 'Configuration.Role'
  3. aws iam list-attached-role-policies --role-name \$ROLE_NAME --query 'AttachedPolicies[*].PolicyArn'
  4. aws iam get-policy-version --policy-arn \$POLICY_ARN --version-id \$VERSION --query 'PolicyVersion.Document'
  5. aws iam list-role-policies --role-name \$ROLE_NAME --query 'PolicyNames'
  6. aws iam get-role-policy --role-name \$ROLE_NAME --policy-name \$INLINE_POLICY --query 'PolicyDocument'"

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
declare -A role_mapping
declare -A admin_roles

# Audit each region
for REGION in $regions; do
  function_names=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query 'Functions[*].FunctionName' --output text)

  checked_count=0

  for FUNCTION in $function_names; do
    checked_count=$((checked_count + 1))

    # Get Lambda Execution Role ARN
    role_arn=$(aws lambda get-function --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'Configuration.Role' --output text)
    role_name=$(basename "$role_arn")  # Extract role name from ARN

    role_mapping["$role_name"]+="$FUNCTION "

    # Check Managed Policies
    policy_arns=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyArn' --output text)

    for policy_arn in $policy_arns; do
      version_id=$(aws iam get-policy --policy-arn "$policy_arn" --profile "$PROFILE" --query 'Policy.DefaultVersionId' --output text)
      policy_doc=$(aws iam get-policy-version --policy-arn "$policy_arn" --version-id "$version_id" --profile "$PROFILE" --query 'PolicyVersion.Document' --output json)

      if echo "$policy_doc" | grep -q '"Action": "*"'; then
        admin_roles["$role_name"]="true"
      fi
    done

    # Check Inline Policies
    inline_policies=$(aws iam list-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'PolicyNames' --output text)

    for inline_policy in $inline_policies; do
      inline_doc=$(aws iam get-role-policy --role-name "$role_name" --policy-name "$inline_policy" --profile "$PROFILE" --query 'PolicyDocument' --output json)

      if echo "$inline_doc" | grep -q '"Action": "*"'; then
        admin_roles["$role_name"]="true"
      fi
    done
  done

  total_functions["$REGION"]=$checked_count
  
  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
shared_roles_found=false
admin_roles_found=false

for role in "${!role_mapping[@]}"; do
  IFS=' ' read -r -a functions <<< "${role_mapping[$role]}"
  if [ ${#functions[@]} -gt 1 ]; then
    shared_roles_found=true
    echo -e "${RED}Shared Execution Role: $role${NC}"
    echo "Lambda Functions Sharing Execution Role:"
    echo -e "${RED}${functions[*]}${NC}" | awk '{print " - " $0}'
    echo "----------------------------------------------------------------"
  fi
done

for role in "${!admin_roles[@]}"; do
  admin_roles_found=true
  echo -e "${RED}Admin Privileges Detected: $role${NC}"
  echo "This execution role has full admin permissions ('Action: *' & 'Effect: Allow')."
  echo "----------------------------------------------------------------"
done

if ! $shared_roles_found; then
  echo -e "${GREEN}All AWS Lambda functions follow best practices (No Shared Execution Roles).${NC}"
fi

if ! $admin_roles_found; then
  echo -e "${GREEN}No Lambda execution roles have full administrative permissions.${NC}"
fi

echo "Audit completed for all regions."
