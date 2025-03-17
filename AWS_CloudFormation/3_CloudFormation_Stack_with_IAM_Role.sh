#!/bin/bash

# Description and Criteria
description="AWS Audit for IAM Roles Attached to CloudFormation Stacks"
criteria="Verifies whether CloudFormation stacks use IAM roles with excessive permissions, violating the Principle of Least Privilege (POLP)."

# Commands Used
command_used="Commands Used:
1. aws cloudformation list-stacks --region \$REGION --stack-status-filter CREATE_COMPLETE --query 'StackSummaries[*].StackName' --output text
2. aws cloudformation describe-stacks --region \$REGION --stack-name \$STACK_NAME --query 'Stacks[*].RoleARN' --output text
3. aws iam list-attached-role-policies --role-name \$ROLE_NAME
4. aws iam get-policy --policy-arn \$POLICY_ARN
5. aws iam list-role-policies --role-name \$ROLE_NAME
6. aws iam get-role-policy --role-name \$ROLE_NAME --policy-name \$INLINE_POLICY_NAME"

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
    role_arn=$(aws cloudformation describe-stacks --region "$REGION" --profile "$PROFILE" --stack-name "$STACK_NAME" --query 'Stacks[*].RoleARN' --output text 2>/dev/null)

    if [ -z "$role_arn" ] || [ "$role_arn" == "None" ]; then
      continue
    fi

    role_name=$(basename "$role_arn")

    # Check Managed Policies
    managed_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null)

    for policy_arn in $managed_policies; do
      policy_doc=$(aws iam get-policy --policy-arn "$policy_arn" --profile "$PROFILE" --query 'Policy.DefaultVersionId' --output text 2>/dev/null)
      
      if [ "$policy_doc" == "AdministratorAccess" ]; then
        non_compliant_stacks["$REGION"]+="$STACK_NAME (Excessive Managed Policy: $policy_arn) "
      fi
    done

    # Check Inline Policies
    inline_policies=$(aws iam list-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'PolicyNames' --output text 2>/dev/null)

    for inline_policy in $inline_policies; do
      policy_json=$(aws iam get-role-policy --role-name "$role_name" --policy-name "$inline_policy" --profile "$PROFILE" --query 'PolicyDocument' --output json 2>/dev/null)
      
      if echo "$policy_json" | grep -q '"Effect": "Allow"' && echo "$policy_json" | grep -q '"Action": "*"' && echo "$policy_json" | grep -q '"Resource": "*"'; then
        non_compliant_stacks["$REGION"]+="$STACK_NAME (Overly Permissive Inline Policy: $inline_policy) "
      fi
    done
  done
done

# Display audit summary
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
  echo -e "${GREEN}All CloudFormation stacks have IAM roles with least privilege.${NC}"
fi

echo "Audit completed for all regions."
