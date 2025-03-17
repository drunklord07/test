#!/bin/bash

# Description and Criteria
description="AWS Audit for Load Balancer Deletion Protection"
criteria="This script checks whether Deletion Protection is enabled for Application and Network Load Balancers (ALBs & NLBs) across all AWS regions."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`application\`) || (Type == \`network\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-load-balancer-attributes --region \$REGION --load-balancer-arn \$LB_ARN --query 'Attributes[?(Key == \`deletion_protection.enabled\`)].Value' --output text"

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

declare -A total_lbs
declare -A non_compliant_lbs

# Audit each region
for REGION in $regions; do
  # Get all ALB & NLB ARNs
  lb_arns=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `application`) || (Type == `network`)].LoadBalancerArn' --output text)

  lb_count=0
  non_compliant_list=()

  for LB_ARN in $lb_arns; do
    ((lb_count++))

    # Get Deletion Protection status
    DELETION_PROTECTION=$(aws elbv2 describe-load-balancer-attributes --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$LB_ARN" --query 'Attributes[?(Key == `deletion_protection.enabled`)].Value' --output text)

    if [[ "$DELETION_PROTECTION" != "true" ]]; then
      non_compliant_list+=("$LB_ARN (Deletion Protection Disabled)")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  non_compliant_lbs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-21s |\n" "$REGION" "$lb_count"
done

echo "+--------------+---------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Load Balancers:${NC}"
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
  echo -e "${GREEN}All Load Balancers have Deletion Protection enabled.${NC}"
fi

echo "Audit completed for all regions."
