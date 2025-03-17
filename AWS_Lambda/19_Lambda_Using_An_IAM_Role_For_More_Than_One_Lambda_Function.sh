#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Execution Role Sharing (Principle of Least Privilege Violation)"
criteria="This script checks if multiple AWS Lambda functions are sharing the same execution role, violating the Principle of Least Privilege (POLP)."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function --region \$REGION --function-name \$FUNCTION --query 'Configuration.Role'"

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
declare -A role_mappings

# Audit each region
for REGION in $regions; do
  function_names=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query 'Functions[*].FunctionName' --output text)

  checked_count=0
  declare -A execution_roles

  for FUNCTION in $function_names; do
    checked_count=$((checked_count + 1))

    # Get Lambda execution role ARN
    role_arn=$(aws lambda get-function --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'Configuration.Role' --output text 2>/dev/null)

    if [[ -n "$role_arn" ]]; then
      execution_roles["$FUNCTION"]="$role_arn"
    fi
  done

  total_functions["$REGION"]=$checked_count
  role_mappings["$REGION"]=$(declare -p execution_roles)

  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
violation_found=false

echo -e "${PURPLE}Checking for Lambda functions sharing execution roles...${NC}"

for region in "${!role_mappings[@]}"; do
  eval "declare -A functions_in_region=${role_mappings[$region]}"
  
  declare -A role_usage
  for function in "${!functions_in_region[@]}"; do
    role_usage["${functions_in_region[$function]}"]+="$function "
  done

  # Find shared roles
  shared_roles=()
  for role in "${!role_usage[@]}"; do
    function_list=(${role_usage[$role]})
    if [[ ${#function_list[@]} -gt 1 ]]; then
      shared_roles+=("$role")
    fi
  done

  if [[ ${#shared_roles[@]} -gt 0 ]]; then
    violation_found=true
    echo -e "${RED}Region: $region${NC}"
    echo "Lambda Functions Sharing IAM Execution Roles:"
    for role in "${shared_roles[@]}"; do
      echo -e "${RED}IAM Role: $role${NC}"
      echo "Shared by:"
      for function in ${role_usage[$role]}; do
        echo -e "  - $function"
      done
      echo "----------------------------------------------------------------"
    done
  fi
done

if [[ "$violation_found" = false ]]; then
  echo -e "${GREEN}All AWS Lambda functions have unique execution roles. No POLP violations found.${NC}"
fi

echo "Audit completed for all regions."
