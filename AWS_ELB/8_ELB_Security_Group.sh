#!/bin/bash

# Description and Criteria
description="AWS Audit for Classic Load Balancers with Missing Security Groups"
criteria="This script checks if Classic Load Balancers are associated with security groups that no longer exist."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elb describe-load-balancers --region \$REGION --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text
  3. aws elb describe-load-balancers --region \$REGION --load-balancer-name \$LB_NAME --query 'LoadBalancerDescriptions[*].SourceSecurityGroup.GroupName' --output text
  4. aws ec2 describe-security-groups --region \$REGION --group-names \$SG_NAME --query 'SecurityGroups[*].GroupId' --output text"

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
echo "Region         | Total Load Balancers | Non-Compliant Load Balancers "
echo "+--------------+---------------------+------------------------------+"

declare -A non_compliant_lbs
declare -A total_lbs

# Audit each region
for REGION in $regions; do
  # Get all Classic Load Balancer names
  lb_names=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

  lb_count=0
  non_compliant_list=()

  for LB_NAME in $lb_names; do
    ((lb_count++))

    # Get security group associated with the Load Balancer
    SG_NAME=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" \
      --load-balancer-name "$LB_NAME" \
      --query 'LoadBalancerDescriptions[*].SourceSecurityGroup.GroupName' --output text)

    if [ -z "$SG_NAME" ]; then
      non_compliant_list+=("$LB_NAME (No SG assigned)")
      continue
    fi

    # Check if security group exists
    SG_EXISTS=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --group-names "$SG_NAME" --query 'SecurityGroups[*].GroupId' --output text 2>&1)

    if [[ $SG_EXISTS == *"InvalidGroup.NotFound"* ]]; then
      non_compliant_list+=("$LB_NAME (Missing SG: $SG_NAME)")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  non_compliant_lbs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-19s | %-28s |\n" "$REGION" "$lb_count" "${#non_compliant_list[@]}"
done

echo "+--------------+---------------------+------------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Load Balancers (Missing Security Groups):${NC}"
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
  echo -e "${GREEN}All Classic Load Balancers have valid security groups.${NC}"
fi

echo "Audit completed for all regions."
