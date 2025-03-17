#!/bin/bash

# Description and Criteria
description="AWS Audit for CloudFormation Stack Deletion Policies"
criteria="This script checks if AWS CloudFormation stacks have a DeletionPolicy attribute set in their template to prevent unintended deletions."

# Commands used
command_used="Commands Used:
  1. aws cloudformation list-stacks --region \$REGION --query 'StackSummaries[*].StackName' --output text
  2. aws cloudformation get-template --region \$REGION --stack-name \$STACK_NAME --query 'TemplateBody' --output json"

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
echo "Region         | Total Stacks"
echo "+--------------+--------------+"

declare -A total_stacks
declare -A non_compliant_stacks

# Audit each region
for REGION in $regions; do
  stacks=$(aws cloudformation list-stacks --region "$REGION" --profile "$PROFILE" --query 'StackSummaries[*].StackName' --output text 2>/dev/null)

  stack_count=0
  non_compliant_list=()

  for STACK_NAME in $stacks; do
    ((stack_count++))

    template_body=$(aws cloudformation get-template --region "$REGION" --profile "$PROFILE" --stack-name "$STACK_NAME" --query 'TemplateBody' --output json 2>/dev/null)

    if ! echo "$template_body" | grep -q '"DeletionPolicy"\s*:\s*"Retain"' && ! echo "$template_body" | grep -q 'DeletionPolicy:\s*Retain'; then
      non_compliant_list+=("$STACK_NAME (No DeletionPolicy Configured)")
    fi
  done

  total_stacks["$REGION"]=$stack_count
  non_compliant_stacks["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-14s |\n" "$REGION" "$stack_count"
done

echo "+--------------+--------------+"
echo ""

# Audit Section
if [ ${#non_compliant_stacks[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant CloudFormation Stacks:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_stacks[@]}"; do
    if [[ -n "${non_compliant_stacks[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Stacks:"
      for stack in ${non_compliant_stacks[$region]}; do
        echo " - $stack"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All CloudFormation stacks have a DeletionPolicy configured.${NC}"
fi

echo "Audit completed for all regions."
