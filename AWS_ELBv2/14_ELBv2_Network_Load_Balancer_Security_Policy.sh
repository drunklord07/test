#!/bin/bash

# Description and Criteria
description="AWS Audit for Network Load Balancer (NLB) TLS Security Policy"
criteria="This script checks if NLBs are using an outdated TLS security policy."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`network\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$LB_ARN --query 'Listeners[*].SslPolicy' --output text"

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
echo "Region         | Total NLBs "
echo "+--------------+------------+"

declare -A total_nlbs
declare -A outdated_nlbs

# Audit each region
for REGION in $regions; do
  # Get all Network Load Balancer ARNs
  nlbs=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `network`)].LoadBalancerArn' --output text)

  nlb_count=0
  outdated_policy_list=()

  for LB_ARN in $nlbs; do
    ((nlb_count++))

    # Get TLS Security Policy for Load Balancer
    ssl_policy=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$LB_ARN" --query 'Listeners[*].SslPolicy' --output text)

    if [[ "$ssl_policy" != "ELBSecurityPolicy-TLS13-1-2-2021-06" ]]; then
      outdated_policy_list+=("$LB_ARN ($ssl_policy)")
    fi
  done

  total_nlbs["$REGION"]=$nlb_count

  printf "| %-14s | %-10s |\n" "$REGION" "$nlb_count"
done

echo "+--------------+------------+"
echo ""

# Audit Section
if [ ${#outdated_nlbs[@]} -gt 0 ]; then
  echo -e "${RED}NLBs Using Outdated TLS Policies:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!outdated_nlbs[@]}"; do
    if [[ "${#outdated_nlbs[$region]}" -gt 0 ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Outdated TLS Policies:"
      for nlb in "${outdated_nlbs[$region]}"; do
        echo " - $nlb"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All NLBs use a secure TLS policy.${NC}"
fi

echo "Audit completed for all regions."
