#!/bin/bash

# Description and Criteria
description="AWS Audit for Unrestricted Access in VPC Endpoints"
criteria="This script identifies VPC endpoints with policies allowing access to any principal ('*') without conditions."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-vpc-endpoints --region REGION --query 'VpcEndpoints[*].VpcEndpointId'
  3. aws ec2 describe-vpc-endpoints --region REGION --vpc-endpoint-ids VPCE_ID --query 'VpcEndpoints[*].PolicyDocument'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
echo "\n+----------------+----------------+"
echo "| Region         | VPC Endpoint Count |"
echo "+----------------+----------------+"

# Dictionary for storing VPC endpoint counts
declare -A vpc_endpoint_counts

# Audit each region
for REGION in $regions; do
  vpces=$(aws ec2 describe-vpc-endpoints --region "$REGION" --profile "$PROFILE" --query 'VpcEndpoints[*].VpcEndpointId' --output text)
  vpce_count=$(echo "$vpces" | wc -w)
  vpc_endpoint_counts["$REGION"]=$vpce_count

  printf "| %-14s | %-18s |\n" "$REGION" "$vpce_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each VPC Endpoint for compliance
for REGION in "${!vpc_endpoint_counts[@]}"; do
  if [ "${vpc_endpoint_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"
    non_compliant_found=0

    for VPCE_ID in $(aws ec2 describe-vpc-endpoints --region "$REGION" --profile "$PROFILE" --query 'VpcEndpoints[*].VpcEndpointId' --output text); do
      # Get VPC Endpoint policy document
      policy_doc=$(aws ec2 describe-vpc-endpoints --region "$REGION" --profile "$PROFILE" --vpc-endpoint-ids "$VPCE_ID" --query 'VpcEndpoints[*].PolicyDocument' --output text 2>/dev/null)

      # Check if policy_doc is empty or null
      if [ -z "$policy_doc" ] || [ "$policy_doc" == "null" ]; then
        continue
      fi

      # Check for open access (Principal: "*") and no Condition
      if echo "$policy_doc" | grep -q '"Principal"[[:space:]]*:[[:space:]]*"\*"'; then
        if ! echo "$policy_doc" | grep -q '"Condition"'; then
          non_compliant_found=1
          echo "--------------------------------------------------"
          echo "Region: $REGION"
          echo "VPC Endpoint ID: $VPCE_ID"
          echo -e "Status: ${RED}Non-Compliant (Unrestricted Access)${NC}"
          echo "--------------------------------------------------"
        fi
      else
        echo -e "${GREEN}Region: $REGION | VPC Endpoint ID: $VPCE_ID | Status: Compliant${NC}"
      fi
    done

    if [[ "$non_compliant_found" -eq 0 ]]; then
      echo -e "${GREEN}All VPC Endpoints in region $REGION are compliant!${NC}"
    fi
  fi
done

echo "Audit completed for all regions."
