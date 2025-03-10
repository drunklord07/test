#!/bin/bash

# Description and Criteria
description="AWS Audit for Internet Gateway (IGW) & NAT Gateway (NGW) VPC Attachments"
criteria="This script identifies IGWs and NGWs that are not properly attached to their associated VPCs, making them non-compliant."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-internet-gateways --region \$REGION --query 'InternetGateways[*]'
  3. aws ec2 describe-nat-gateways --region \$REGION --query 'NatGateways[*]'"

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
echo "\n+----------------+----------------+----------------+"
echo "| Region         | IGW Count      | NGW Count      |"
echo "+----------------+----------------+----------------+"

# Dictionaries for storing counts
declare -A igw_counts
declare -A ngw_counts

# Audit each region
for REGION in $regions; do
  # Count IGWs
  igws=$(aws ec2 describe-internet-gateways --region "$REGION" --profile "$PROFILE" \
    --query 'InternetGateways[*].InternetGatewayId' --output text)
  igw_count=$(echo "$igws" | wc -w)
  igw_counts[$REGION]=$igw_count

  # Count NGWs
  ngws=$(aws ec2 describe-nat-gateways --region "$REGION" --profile "$PROFILE" \
    --query 'NatGateways[*].NatGatewayId' --output text)
  ngw_count=$(echo "$ngws" | wc -w)
  ngw_counts[$REGION]=$ngw_count

  printf "| %-14s | %-14s | %-14s |\n" "$REGION" "$igw_count" "$ngw_count"
done
echo "+----------------+----------------+----------------+"
echo ""

# Audit each IGW & NGW for compliance
for REGION in "${!igw_counts[@]}"; do
  if [ "${igw_counts[$REGION]}" -gt 0 ] || [ "${ngw_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    # IGW Compliance Check
    for IGW_ID in $(aws ec2 describe-internet-gateways --region "$REGION" --profile "$PROFILE" \
      --query 'InternetGateways[*].InternetGatewayId' --output text); do

      attached_vpc=$(aws ec2 describe-internet-gateways --region "$REGION" --profile "$PROFILE" \
        --internet-gateway-ids "$IGW_ID" --query 'InternetGateways[*].Attachments[?State==`available`].VpcId' --output text)

      if [ -z "$attached_vpc" ]; then
        STATUS="${RED}Non-Compliant (IGW Not Attached)${NC}"
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "IGW ID: $IGW_ID"
        echo "Status: $STATUS"
        echo "--------------------------------------------------"
      fi
    done

    # NGW Compliance Check
    for NGW_ID in $(aws ec2 describe-nat-gateways --region "$REGION" --profile "$PROFILE" \
      --query 'NatGateways[*].NatGatewayId' --output text); do

      attached_vpc=$(aws ec2 describe-nat-gateways --region "$REGION" --profile "$PROFILE" \
        --nat-gateway-ids "$NGW_ID" --query 'NatGateways[*].VpcId' --output text)

      if [ -z "$attached_vpc" ]; then
        STATUS="${RED}Non-Compliant (NGW Not Attached)${NC}"
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "NGW ID: $NGW_ID"
        echo "Status: $STATUS"
        echo "--------------------------------------------------"
      fi
    done
  fi
done

echo "Audit completed for all regions."
