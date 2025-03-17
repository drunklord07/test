#!/bin/bash

# Description and Criteria
description="AWS Audit for Classic Load Balancers Using Outdated SSL Security Policies"
criteria="This script checks if Classic Load Balancers are using outdated SSL security policies."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elb describe-load-balancers --region \$REGION --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text
  3. aws elb describe-load-balancer-policies --region \$REGION --load-balancer-name \$LB_NAME --query 'PolicyDescriptions[*].PolicyName' --output text
  4. aws elb describe-load-balancer-policies --region \$REGION --load-balancer-name \$LB_NAME --policy-name \$POLICY_NAME --query 'PolicyDescriptions[*].PolicyAttributeDescriptions[?(AttributeName == \`Reference-Security-Policy\`)].AttributeValue | []' --output text"

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

# Define latest security policies
latest_policies=("ELBSecurityPolicy-2016-08" "ELBSecurityPolicy-TLS-1-1-2017-01" "ELBSecurityPolicy-TLS-1-2-2017-01")

# Table Header
echo "Region         | Total Load Balancers | Outdated Security Policies "
echo "+--------------+---------------------+-----------------------------+"

declare -A outdated_lbs
declare -A total_lbs

# Audit each region
for REGION in $regions; do
  # Get all Classic Load Balancer names
  lb_names=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

  lb_count=0
  outdated_list=()

  for LB_NAME in $lb_names; do
    ((lb_count++))

    # Get the associated security policy name
    POLICY_NAME=$(aws elb describe-load-balancer-policies --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" \
      --query 'PolicyDescriptions[*].PolicyName' --output text)

    if [ -z "$POLICY_NAME" ]; then
      continue
    fi

    # Get the security policy reference
    SECURITY_POLICY=$(aws elb describe-load-balancer-policies --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" \
      --policy-name "$POLICY_NAME" \
      --query 'PolicyDescriptions[*].PolicyAttributeDescriptions[?(AttributeName == `Reference-Security-Policy`)].AttributeValue | []' \
      --output text)

    # Check if the security policy is outdated
    if [[ ! " ${latest_policies[*]} " =~ " ${SECURITY_POLICY} " ]]; then
      outdated_list+=("$LB_NAME")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  outdated_lbs["$REGION"]="${outdated_list[*]}"

  printf "| %-14s | %-19s | %-27s |\n" "$REGION" "$lb_count" "${#outdated_list[@]}"
done

echo "+--------------+---------------------+-----------------------------+"
echo ""

# Audit Section
if [ ${#outdated_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Classic Load Balancers Using Outdated Security Policies (Require Security Review):${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!outdated_lbs[@]}"; do
    if [[ -n "${outdated_lbs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Load Balancers with Outdated Policies:"
      echo -e "${outdated_lbs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Classic Load Balancers have the latest security policies.${NC}"
fi

echo "Audit completed for all regions."
