#!/bin/bash

# Description and Criteria
description="AWS Audit for Lambda Cross-Account Access (Insecure Policy Check)"
criteria="This script checks if AWS Lambda functions have insecure cross-account access permissions in their resource-based policies."

# Commands used
command_used="Commands Used:
  1. aws lambda list-functions --region \$REGION --query 'Functions[*].FunctionName'
  2. aws lambda get-policy --region \$REGION --function-name \$FUNCTION --query 'Policy'"

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
declare -A insecure_functions

# Define trusted AWS accounts (Replace with actual trusted AWS Account ARNs)
trusted_accounts=(
  "arn:aws:iam::123456789012:root"
  "arn:aws:iam::111122223333:root"
)

# Audit each region
for REGION in $regions; do
  function_names=$(aws lambda list-functions --region "$REGION" --profile "$PROFILE" --query 'Functions[*].FunctionName' --output text)

  checked_count=0
  insecure_list=()

  for FUNCTION in $function_names; do
    checked_count=$((checked_count + 1))

    # Get Lambda policy (if exists)
    policy_json=$(aws lambda get-policy --region "$REGION" --profile "$PROFILE" --function-name "$FUNCTION" --query 'Policy' --output text 2>/dev/null)

    if [[ -n "$policy_json" ]]; then
      # Extract principal ARNs from policy
      principal_arns=$(echo "$policy_json" | jq -r '.Statement[].Principal.AWS' | tr -d '"')

      for arn in $principal_arns; do
        if [[ ! " ${trusted_accounts[@]} " =~ " ${arn} " ]]; then
          insecure_list+=("$FUNCTION (Cross-Account: $arn)")
        fi
      done
    fi
  done

  total_functions["$REGION"]=$checked_count
  insecure_functions["$REGION"]="${insecure_list[*]}"
  
  printf "| %-14s | %-16s |\n" "$REGION" "$checked_count"
done

echo "+--------------+----------------+"
echo ""

# Audit Section
if [ ${#insecure_functions[@]} -gt 0 ]; then
  echo -e "${RED}Lambda Functions with Insecure Cross-Account Access:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!insecure_functions[@]}"; do
    if [[ -n "${insecure_functions[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Lambda Functions with Insecure Cross-Account Access:"
      echo -e "${RED}${insecure_functions[$region]}${NC}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS Lambda functions have secure cross-account access policies.${NC}"
fi

echo "Audit completed for all regions."
