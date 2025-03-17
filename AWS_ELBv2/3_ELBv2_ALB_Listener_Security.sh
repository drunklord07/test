#!/bin/bash

# Description and Criteria
description="AWS Audit for Application Load Balancers (ALBs) - HTTPS Listener Compliance"
criteria="This script checks if ALBs have at least one listener configured with the HTTPS protocol."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$ALB_ARN --query 'Listeners[*].Protocol' --output text"

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
echo "Region         | Total ALBs "
echo "+--------------+-----------+"

declare -A total_albs
declare -A non_compliant_albs

# Audit each region
for REGION in $regions; do
  # Get all ALB ARNs
  alb_arns=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `application`)].LoadBalancerArn' --output text)

  alb_count=0
  non_compliant_list=()

  for ALB_ARN in $alb_arns; do
    ((alb_count++))

    # Get listener protocols
    PROTOCOLS=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$ALB_ARN" \
      --query 'Listeners[*].Protocol' --output text)

    # Check if HTTPS is present
    if [[ ! "$PROTOCOLS" =~ "HTTPS" ]]; then
      non_compliant_list+=("$ALB_ARN")
    fi
  done

  total_albs["$REGION"]=$alb_count
  non_compliant_albs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-9s |\n" "$REGION" "$alb_count"
done

echo "+--------------+-----------+"
echo ""

# Audit Section
if [ ${#non_compliant_albs[@]} -gt 0 ]; then
  echo -e "${RED}ALBs without HTTPS Listener Configuration:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_albs[@]}"; do
    if [[ -n "${non_compliant_albs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant ALBs:"
      echo -e "${non_compliant_albs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Application Load Balancers have at least one HTTPS listener.${NC}"
fi

echo "Audit completed for all regions."
