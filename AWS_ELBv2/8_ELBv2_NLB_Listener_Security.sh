#!/bin/bash

# Description and Criteria
description="AWS Audit for Network Load Balancer (NLB) TLS Termination"
criteria="This script checks whether Network Load Balancers (NLBs) have at least one TLS listener configured across all AWS regions."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`network\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$LB_ARN --query 'Listeners[*].Protocol' --output text"

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
echo "Region         | Total NLBs  "
echo "+--------------+------------+"

declare -A total_nlbs
declare -A non_compliant_nlbs

# Audit each region
for REGION in $regions; do
  # Get all NLB ARNs
  nlbs=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `network`)].LoadBalancerArn' --output text)

  nlb_count=0
  non_compliant_list=()

  for LB_ARN in $nlbs; do
    ((nlb_count++))

    # Get listener protocols
    protocols=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$LB_ARN" --query 'Listeners[*].Protocol' --output text)

    # Check if TLS is present
    if ! echo "$protocols" | grep -q "TLS"; then
      non_compliant_list+=("$LB_ARN (No TLS Listener Configured)")
    fi
  done

  total_nlbs["$REGION"]=$nlb_count
  non_compliant_nlbs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-10s |\n" "$REGION" "$nlb_count"
done

echo "+--------------+------------+"
echo ""

# Audit Section
if [ ${#non_compliant_nlbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Network Load Balancers:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_nlbs[@]}"; do
    if [[ -n "${non_compliant_nlbs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant NLBs:"
      echo -e "${non_compliant_nlbs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Network Load Balancers have TLS listeners configured.${NC}"
fi

echo "Audit completed for all regions."
