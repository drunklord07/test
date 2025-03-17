#!/bin/bash

# Description and Criteria
description="AWS Audit for ALB SSL Policies"
criteria="This script checks ALBs for outdated or insecure SSL policies that may leave the load balancer vulnerable to exploits."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$ALB_ARN --query 'Listeners[*].SslPolicy' --output text"

# Latest approved SSL policies
LATEST_SSL_POLICIES=("ELBSecurityPolicy-TLS-1-2-2017-01" "ELBSecurityPolicy-FS-1-2-Res-2020-10" "ELBSecurityPolicy-TLS-1-2-Ext-2018-06")

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

    # Get SSL policies
    SSL_POLICY=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$ALB_ARN" --query 'Listeners[*].SslPolicy' --output text)

    if [[ -n "$SSL_POLICY" ]]; then
      if [[ ! " ${LATEST_SSL_POLICIES[@]} " =~ " ${SSL_POLICY} " ]]; then
        non_compliant_list+=("$ALB_ARN (Insecure SSL Policy: $SSL_POLICY)")
      fi
    else
      non_compliant_list+=("$ALB_ARN (No SSL policy configured)")
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
  echo -e "${RED}Non-Compliant ALBs:${NC}"
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
  echo -e "${GREEN}All ALBs have secure SSL policies.${NC}"
fi

echo "Audit completed for all regions."
