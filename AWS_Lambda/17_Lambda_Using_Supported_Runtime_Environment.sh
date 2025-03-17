#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Function Runtimes (Outdated Runtime Check)"
criteria="This script checks if AWS Lambda functions are using outdated runtimes based on AWS-supported versions."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function-configuration --region \$REGION --function-name \$FUNCTION --query 'Runtime'"

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

# List of AWS-supported Lambda runtimes (latest based on provided data)
supported_runtimes=(
  "nodejs22.x"
  "nodejs20.x"
  "nodejs18.x"
  "python3.13"
  "python3.12"
  "python3.11"
  "python3.10"
  "python3.9"
  "java21"
  "java17"
  "java11"
  "java8.al2"
  "dotnet9"
  "dotnet8"
  "ruby3.3"
  "ruby3.2"
  "provided.al2023"
  "provided.al2"
)

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Lambda Functions"
echo "+--------------+----------------+"

declare -A total_functions
declare -A outdated_functions

# Audit each region
for REGION in $regions; do
  function_names=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query 'Functions[*].FunctionName' --output text)

  checked_count=0
  outdated_list=()

  for FUNCTION in $function_names; do
    checked_count=$((checked_count + 1))

    # Get Lambda runtime
    runtime=$(aws lambda get-function-configuration --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'Runtime' --output text)

    # Check if runtime is outdated
    if [[ ! " ${supported_runtimes[@]} " =~ " ${runtime} " ]]; then
      outdated_list+=("$FUNCTION ($runtime)")
    fi
  done

  total_functions["$REGION"]=$checked_count
  outdated_functions["$REGION"]="${outdated_list[*]}"
  
  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
if [ ${#outdated_functions[@]} -gt 0 ]; then
  echo -e "${RED}Lambda Functions Using Outdated Runtimes:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!outdated_functions[@]}"; do
    if [[ -n "${outdated_functions[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Lambda Functions Using Outdated Runtimes:"
      echo -e "${RED}${outdated_functions[$region]}${NC}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS Lambda functions are using supported runtimes.${NC}"
fi

echo "Audit completed for all regions."
