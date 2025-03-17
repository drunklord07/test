#!/bin/bash

# Description and Criteria
description="AWS Audit for Classic Load Balancers Without Secure HTTPS/SSL Listeners"
criteria="This script checks if Classic Load Balancers lack HTTPS or SSL listeners, which means front-end traffic is unencrypted."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elb describe-load-balancers --region \$REGION --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text
  3. aws elb describe-load-balancers --region \$REGION --load-balancer-name \$LB_NAME --query \"LoadBalancerDescriptions[*].{ListenerDescriptions:ListenerDescriptions[?Listener.Protocol == 'HTTPS' || Listener.Protocol == 'SSL']}\" --output text"

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
echo "Region         | Total Load Balancers | Non-Secure Load Balancers "
echo "+--------------+---------------------+-----------------------------+"

declare -A non_secure_lbs
declare -A total_lbs

# Audit each region
for REGION in $regions; do
  # Get all Classic Load Balancer names
  lb_names=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

  lb_count=0
  non_secure_list=()

  for LB_NAME in $lb_names; do
    ((lb_count++))

    # Check if load balancer has HTTPS/SSL listeners
    LISTENERS=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" \
      --query "LoadBalancerDescriptions[*].{ListenerDescriptions:ListenerDescriptions[?Listener.Protocol == 'HTTPS' || Listener.Protocol == 'SSL']}" \
      --output text)

    if [ -z "$LISTENERS" ]; then
      non_secure_list+=("$LB_NAME")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  non_secure_lbs["$REGION"]="${non_secure_list[*]}"

  printf "| %-14s | %-19s | %-27s |\n" "$REGION" "$lb_count" "${#non_secure_list[@]}"
done

echo "+--------------+---------------------+-----------------------------+"
echo ""

# Audit Section
if [ ${#non_secure_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Classic Load Balancers Without HTTPS/SSL Listeners (Require Security Review):${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_secure_lbs[@]}"; do
    if [[ -n "${non_secure_lbs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Secure Load Balancers:"
      echo -e "${non_secure_lbs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Classic Load Balancers have HTTPS/SSL listeners.${NC}"
fi

echo "Audit completed for all regions."
