#!/bin/bash

# Description and Criteria
description="AWS Audit for NLB TLS ALPN Policy Configuration"
criteria="This script checks whether Network Load Balancers (NLBs) have a TLS ALPN policy configured."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`network\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$NLB_ARN --query 'Listeners[?(Protocol == \`TLS\`)].AlpnPolicy' --output text"

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
declare -A non_compliant_nlbs

# Audit each region
for REGION in $regions; do
  # Get all NLB ARNs
  nlbs=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `network`)].LoadBalancerArn' --output text)

  nlb_count=0
  non_compliant_list=()

  for NLB_ARN in $nlbs; do
    ((nlb_count++))

    # Get ALPN Policy for TLS Listeners
    alpn_policy=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$NLB_ARN" --query 'Listeners[?(Protocol == `TLS`)].AlpnPolicy' --output text)

    if [[ "$alpn_policy" == "[]" || -z "$alpn_policy" ]]; then
      non_compliant_list+=("$NLB_ARN (No TLS ALPN Policy Configured)")
    fi
  done

  total_nlbs["$REGION"]=$nlb_count

  printf "| %-14s | %-10s |\n" "$REGION" "$nlb_count"
done

echo "+--------------+------------+"
echo ""

# Audit Section
if [ ${#non_compliant_nlbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Network Load Balancers:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_nlbs[@]}"; do
    if [[ "${#non_compliant_nlbs[$region]}" -gt 0 ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant NLBs:"
      for n in "${non_compliant_nlbs[$region]}"; do
        echo " - $n"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Network Load Balancers have a TLS ALPN Policy configured.${NC}"
fi

echo "Audit completed for all regions."
