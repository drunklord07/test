#!/bin/bash

# Description and Criteria
description="AWS Audit for ELBv2 Load Balancer Scheme Configuration"
criteria="This script checks whether Application and Network Load Balancers (ALBs/NLBs) are internet-facing."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`application\`) || (Type == \`network\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-load-balancers --region \$REGION --load-balancer-arns \$LB_ARN --query 'LoadBalancers[*].Scheme' --output text"

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
echo "Region         | Total ELBs "
echo "+--------------+------------+"

declare -A total_elbs
declare -A internet_facing_elbs

# Audit each region
for REGION in $regions; do
  # Get all ALB and NLB ARNs
  elbs=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `application` || Type == `network`)].LoadBalancerArn' --output text)

  elb_count=0
  internet_facing_list=()

  for LB_ARN in $elbs; do
    ((elb_count++))

    # Get Scheme for Load Balancer
    scheme=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arns "$LB_ARN" --query 'LoadBalancers[*].Scheme' --output text)

    if [[ "$scheme" == "internet-facing" ]]; then
      internet_facing_list+=("$LB_ARN (Internet-Facing)")
    fi
  done

  total_elbs["$REGION"]=$elb_count

  printf "| %-14s | %-10s |\n" "$REGION" "$elb_count"
done

echo "+--------------+------------+"
echo ""

# Audit Section
if [ ${#internet_facing_elbs[@]} -gt 0 ]; then
  echo -e "${RED}Internet-Facing Load Balancers:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!internet_facing_elbs[@]}"; do
    if [[ "${#internet_facing_elbs[$region]}" -gt 0 ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Internet-Facing ELBs:"
      for elb in "${internet_facing_elbs[$region]}"; do
        echo " - $elb"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Load Balancers are internal.${NC}"
fi

echo "Audit completed for all regions."
