#!/bin/bash

# Description and Criteria
description="AWS Audit for GWLB Cross-Zone Load Balancing"
criteria="This script checks whether Gateway Load Balancers (GWLBs) have Cross-Zone Load Balancing enabled."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`gateway\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-load-balancer-attributes --region \$REGION --load-balancer-arn \$GWLB_ARN --query 'Attributes[?(Key == \`load_balancing.cross_zone.enabled\`)].Value' --output text"

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
echo "Region         | Total GWLBs "
echo "+--------------+------------+"

declare -A total_gwlbs
declare -A non_compliant_gwlbs

# Audit each region
for REGION in $regions; do
  # Get all GWLB ARNs
  gwlbs=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `gateway`)].LoadBalancerArn' --output text)

  gwlb_count=0
  non_compliant_list=()

  for GWLB_ARN in $gwlbs; do
    ((gwlb_count++))

    # Get Cross-Zone Load Balancing attribute
    cross_zone_enabled=$(aws elbv2 describe-load-balancer-attributes --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$GWLB_ARN" --query 'Attributes[?(Key == `load_balancing.cross_zone.enabled`)].Value' --output text)

    if [[ "$cross_zone_enabled" != "true" ]]; then
      non_compliant_list+=("$GWLB_ARN (Cross-Zone Load Balancing Disabled)")
    fi
  done

  total_gwlbs["$REGION"]=$gwlb_count

  printf "| %-14s | %-10s |\n" "$REGION" "$gwlb_count"
done

echo "+--------------+------------+"
echo ""

# Audit Section
if [ ${#non_compliant_gwlbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Gateway Load Balancers:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_gwlbs[@]}"; do
    if [[ "${#non_compliant_gwlbs[$region]}" -gt 0 ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant GWLBs:"
      for g in "${non_compliant_gwlbs[$region]}"; do
        echo " - $g"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Gateway Load Balancers have Cross-Zone Load Balancing enabled.${NC}"
fi

echo "Audit completed for all regions."
