#!/bin/bash

# Description and Criteria
description="AWS Audit for CloudFormation Stacks with SNS Notifications"
criteria="Verifies whether CloudFormation stacks have Amazon SNS topics configured for event notifications."

# Commands Used
command_used="Commands Used:
1. aws cloudformation list-stacks --region \$REGION --stack-status-filter CREATE_COMPLETE --query 'StackSummaries[*].StackName' --output text
2. aws cloudformation describe-stacks --region \$REGION --stack-name \$STACK_NAME --query 'Stacks[*].NotificationARNs[]' --output text"

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

# Get AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Display quick summary table first
echo "Region         | Total Stacks"
echo "+--------------+-------------+"

declare -A total_stacks

for REGION in $regions; do
  stack_count=$(aws cloudformation list-stacks --region "$REGION" --profile "$PROFILE" --stack-status-filter CREATE_COMPLETE --query 'StackSummaries[*].StackName' --output text 2>/dev/null | wc -w)
  
  total_stacks["$REGION"]=$stack_count
  printf "| %-14s | %-12s |\n" "$REGION" "$stack_count"
done

echo "+--------------+-------------+"
echo ""

# Start detailed audit process
declare -A non_compliant_stacks

for REGION in "${!total_stacks[@]}"; do
  stacks=$(aws cloudformation list-stacks --region "$REGION" --profile "$PROFILE" --stack-status-filter CREATE_COMPLETE --query 'StackSummaries[*].StackName' --output text 2>/dev/null)
  
  for STACK_NAME in $stacks; do
    sns_arns=$(aws cloudformation describe-stacks --region "$REGION" --profile "$PROFILE" --stack-name "$STACK_NAME" --query 'Stacks[*].NotificationARNs[]' --output text 2>/dev/null)

    if [ -z "$sns_arns" ]; then
      non_compliant_stacks["$REGION"]+="$STACK_NAME "
    fi
  done
done

# Display audit summary
if [ ${#non_compliant_stacks[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant CloudFormation Stacks (No SNS Notification Configured):${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_stacks[@]}"; do
    if [[ -n "${non_compliant_stacks[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Stacks without SNS Notifications:"
      for stack in ${non_compliant_stacks[$region]}; do
        echo " - $stack"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All CloudFormation stacks have SNS notifications configured.${NC}"
fi

echo "Audit completed for all regions."
