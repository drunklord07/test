#!/bin/bash

# Description and Criteria
description="AWS Audit for Classic Load Balancers Using Internet-Facing Scheme"
criteria="This script checks if Classic Load Balancers are using an internet-facing scheme, which requires additional security review."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elb describe-load-balancers --region \$REGION --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text
  3. aws elb describe-load-balancers --region \$REGION --load-balancer-name \$LB_NAME --query 'LoadBalancerDescriptions[*].Scheme' --output text"

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
echo "Region         | Total Load Balancers | Internet-Facing Load Balancers "
echo "+--------------+---------------------+--------------------------------+"

declare -A internet_facing_lbs
declare -A total_lbs

# Audit each region
for REGION in $regions; do
  # Get all Classic Load Balancer names
  lb_names=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

  lb_count=0
  internet_facing_list=()

  for LB_NAME in $lb_names; do
    ((lb_count++))

    # Get load balancer scheme
    SCHEME=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" \
      --query 'LoadBalancerDescriptions[*].Scheme' --output text)

    if [ "$SCHEME" == "internet-facing" ]; then
      internet_facing_list+=("$LB_NAME")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  internet_facing_lbs["$REGION"]="${internet_facing_list[*]}"

  printf "| %-14s | %-19s | %-30s |\n" "$REGION" "$lb_count" "${#internet_facing_list[@]}"
done

echo "+--------------+---------------------+--------------------------------+"
echo ""

# Audit Section
if [ ${#internet_facing_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Internet-Facing Load Balancers (Require Security Review):${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!internet_facing_lbs[@]}"; do
    if [[ -n "${internet_facing_lbs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Internet-Facing Load Balancers:"
      echo -e "${internet_facing_lbs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}No internet-facing Classic Load Balancers found.${NC}"
fi

echo "Audit completed for all regions."
