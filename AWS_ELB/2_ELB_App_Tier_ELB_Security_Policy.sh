#!/bin/bash

# Description and Criteria
description="AWS Audit for Latest Security Policy on Classic Load Balancers"
criteria="This script checks if Classic Load Balancers are using the latest security policy for SSL negotiation."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elb describe-load-balancers --region \$REGION --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text
  3. aws elb describe-load-balancer-policies --region \$REGION --load-balancer-name \$LB_NAME --query 'PolicyDescriptions[*].PolicyName' --output text
  4. aws elb describe-load-balancer-policies --region \$REGION --load-balancer-name \$LB_NAME --policy-name \$POLICY_NAME --query 'PolicyDescriptions[*].PolicyAttributeDescriptions[?(AttributeName == \`Reference-Security-Policy\`)].AttributeValue | []' --output text"

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
echo "Region         | Total Load Balancers "
echo "+--------------+---------------------+"

declare -A non_compliant_lbs
declare -A total_lbs

# Define the latest security policy (update as needed)
LATEST_POLICY="ELBSecurityPolicy-TLS-1-2-Ext-2018-06"

# Audit each region
for REGION in $regions; do
  # Get all Classic Load Balancer names
  lb_names=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

  lb_count=0
  non_compliant_list=()

  for LB_NAME in $lb_names; do
    ((lb_count++))
    
    # Get associated security policy
    policy_name=$(aws elb describe-load-balancer-policies --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" \
      --query 'PolicyDescriptions[*].PolicyName' --output text)

    # If no policy is found, consider it non-compliant
    if [[ -z "$policy_name" ]]; then
      non_compliant_list+=("$LB_NAME (No Policy Found)")
      continue
    fi

    # Get the security policy version
    current_policy=$(aws elb describe-load-balancer-policies --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" --policy-name "$policy_name" \
      --query 'PolicyDescriptions[*].PolicyAttributeDescriptions[?(AttributeName == `Reference-Security-Policy`)].AttributeValue | []' --output text)

    # Check if the current policy is not the latest
    if [[ "$current_policy" != "$LATEST_POLICY" ]]; then
      non_compliant_list+=("$LB_NAME ($current_policy)")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  non_compliant_lbs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-19s |\n" "$REGION" "$lb_count"
done

echo "+--------------+---------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Load Balancers (Outdated Security Policy):${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_lbs[@]}"; do
    if [[ -n "${non_compliant_lbs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Load Balancers:"
      echo -e "${non_compliant_lbs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Classic Load Balancers are using the latest security policy.${NC}"
fi

echo "Audit completed for all regions."
