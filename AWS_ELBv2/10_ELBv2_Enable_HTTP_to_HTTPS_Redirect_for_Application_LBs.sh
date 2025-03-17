#!/bin/bash

# Description and Criteria
description="AWS Audit for ALB HTTP to HTTPS Redirection"
criteria="This script checks whether Application Load Balancers (ALBs) have an HTTP listener properly configured to redirect traffic to HTTPS."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$LB_ARN --query 'Listeners[?(Protocol == \`HTTP\`)].ListenerArn' --output text
  4. aws elbv2 describe-rules --region \$REGION --listener-arn \$LISTENER_ARN --query 'Rules[*].Actions | []' --output json"

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
echo "Region         | Total ALBs  "
echo "+--------------+------------+"

declare -A total_albs
declare -A non_compliant_albs

# Audit each region
for REGION in $regions; do
  # Get all ALB ARNs
  albs=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `application`)].LoadBalancerArn' --output text)

  alb_count=0
  non_compliant_list=()

  for LB_ARN in $albs; do
    ((alb_count++))

    # Get HTTP listeners
    http_listeners=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$LB_ARN" --query 'Listeners[?(Protocol == `HTTP`)].ListenerArn' --output text)

    if [[ -z "$http_listeners" ]]; then
      continue
    fi

    for LISTENER_ARN in $http_listeners; do
      # Get listener rules
      listener_rules=$(aws elbv2 describe-rules --region "$REGION" --profile "$PROFILE" \
        --listener-arn "$LISTENER_ARN" --query 'Rules[*].Actions' --output json)

      # Check if any rule contains a redirect action with HTTP_301
      if ! echo "$listener_rules" | grep -q '"Type": "redirect"' || ! echo "$listener_rules" | grep -q '"StatusCode": "HTTP_301"'; then
        non_compliant_list+=("$LB_ARN (No HTTP to HTTPS redirection rule)")
      fi
    done
  done

  total_albs["$REGION"]=$alb_count
  non_compliant_albs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-10s |\n" "$REGION" "$alb_count"
done

echo "+--------------+------------+"
echo ""

# Audit Section
if [ ${#non_compliant_albs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Application Load Balancers:${NC}"
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
  echo -e "${GREEN}All Application Load Balancers have HTTP to HTTPS redirection configured.${NC}"
fi

echo "Audit completed for all regions."
