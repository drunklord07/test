#!/bin/bash

# Description and Criteria
description="AWS Audit for Classic Load Balancer SSL/TLS Security Policies"
criteria="This script checks the SSL/TLS security policies associated with Classic Load Balancers and verifies if only approved ciphers are enabled."

# Approved Ciphers (Only those with an asterisk in AWS documentation)
approved_ciphers=(
  "ECDHE-ECDSA-AES128-GCM-SHA256"
  "ECDHE-RSA-AES128-GCM-SHA256"
  "ECDHE-ECDSA-AES128-SHA256"
  "ECDHE-RSA-AES128-SHA256"
  "ECDHE-ECDSA-AES128-SHA"
  "ECDHE-RSA-AES128-SHA"
  "ECDHE-ECDSA-AES256-GCM-SHA384"
  "ECDHE-RSA-AES256-GCM-SHA384"
  "ECDHE-ECDSA-AES256-SHA384"
  "ECDHE-RSA-AES256-SHA384"
  "ECDHE-RSA-AES256-SHA"
  "ECDHE-ECDSA-AES256-SHA"
  "AES128-GCM-SHA256"
  "AES128-SHA256"
  "AES128-SHA"
  "AES256-GCM-SHA384"
  "AES256-SHA256"
  "AES256-SHA"
)

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

declare -A non_compliant_lbs
declare -A total_lbs

# Audit each region
for REGION in $regions; do
  # Get all Classic Load Balancer names
  lb_names=$(aws elb describe-load-balancers --region "$REGION" --profile "$PROFILE" --query 'LoadBalancerDescriptions[*].LoadBalancerName' --output text)

  lb_count=0
  non_compliant_list=()

  for LB_NAME in $lb_names; do
    ((lb_count++))

    # Get the security policy associated with the load balancer
    security_policy=$(aws elb describe-load-balancer-policies --region "$REGION" --profile "$PROFILE" --load-balancer-name "$LB_NAME" --query 'PolicyDescriptions[*].PolicyName' --output text)
    if [[ -z "$security_policy" ]]; then
      continue
    fi

    # Get the ciphers and protocols configured for the security policy
    policy_attributes=$(aws elb describe-load-balancer-policies --region "$REGION" --profile "$PROFILE" --load-balancer-name "$LB_NAME" --policy-name "$security_policy" --query 'PolicyDescriptions[*].PolicyAttributeDescriptions[*].[AttributeName, AttributeValue]' --output text)

    non_compliant=false

    while read -r attribute_name attribute_value; do
      if [[ "$attribute_value" == "true" ]] && [[ ! " ${approved_ciphers[*]} " =~ " ${attribute_name} " ]]; then
        non_compliant=true
      fi
    done <<< "$policy_attributes"

    if [[ "$non_compliant" == "true" ]]; then
      non_compliant_list+=("$LB_NAME")
    fi
  done

  total_lbs["$REGION"]=$lb_count
  non_compliant_lbs["$REGION"]="${non_compliant_list[*]}"

done

# Audit Summary
echo "Audit Summary:"
echo "Region | Total Load Balancers | Non-Compliant Load Balancers"
echo "-------------------------------------------------------------"
for region in "${!total_lbs[@]}"; do
  printf "%-10s | %-20s | %-30s\n" "$region" "${total_lbs[$region]}" "${#non_compliant_lbs[$region]}"
done

echo ""

# Audit Section
if [ ${#non_compliant_lbs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Load Balancers (Using Insecure Ciphers):${NC}"
  for region in "${!non_compliant_lbs[@]}"; do
    if [[ -n "${non_compliant_lbs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Load Balancers:"
      echo -e "${non_compliant_lbs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All Classic Load Balancers use only approved SSL/TLS configurations.${NC}"
fi

echo "Audit completed for all regions."
