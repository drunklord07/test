#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Code Signing Configuration"
criteria="This script checks all AWS Lambda functions across regions to verify if they have a Code Signing configuration enabled."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-function-code-signing-config --region \$REGION --function-name \$FUNCTION --query 'CodeSigningConfigArn'"

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

    # Check Lambda Code Signing Config
    signing_config=$(aws lambda get-function-code-signing-config --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'CodeSigningConfigArn' --output text 2>/dev/null)

    if [[ "$signing_config" == "None" || "$signing_config" == "null" ]]; then
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
  echo -e "${RED}Non-Compliant Lambda Functions (No Code Signing Configured):${NC}"
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
  echo -e "${GREEN}All AWS Lambda functions have Code Signing enabled.${NC}"
fi

echo "Audit completed for all regions."
