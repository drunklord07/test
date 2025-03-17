#!/bin/bash

# Description and Criteria
description="AWS Audit for Shield Advanced Subscription & NAT Gateway Compliance"
criteria="Checks whether AWS Shield Advanced is enabled and if NAT Gateways exist in each VPC."

# Commands used
command_used="Commands Used:
  1. aws shield describe-subscription --region \$REGION
  2. aws ec2 describe-vpcs --region \$REGION --query 'Vpcs[*].VpcId' --output text
  3. aws ec2 describe-nat-gateways --region \$REGION --filter Name=vpc-id,Values=\$VPC_ID Name=state,Values=available"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
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
echo "Region         | Shield Advanced | NAT Gateways"
echo "+--------------+----------------+-------------+"

declare -A shield_status
declare -A nat_status

# Step 1: Check Shield Advanced Subscription & NAT Gateways in each region
for REGION in $regions; do
    # Check AWS Shield Advanced subscription
    shield_status_raw=$(aws shield describe-subscription --region "$REGION" --profile "$PROFILE" --output text 2>&1)
    if [[ "$shield_status_raw" == *"ResourceNotFoundException"* ]]; then
        shield_status["$REGION"]="Non-Compliant"
        shield_display="${RED}Not Enabled${NC}"
    else
        shield_status["$REGION"]="Compliant"
        shield_display="${GREEN}Enabled${NC}"
    fi

    # Get all VPCs in the region
    vpcs=$(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" --query 'Vpcs[*].VpcId' --output text)
    nat_found=0

    for VPC_ID in $vpcs; do
        nat_gateways=$(aws ec2 describe-nat-gateways --region "$REGION" --profile "$PROFILE" --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' --output text)
        if [[ -n "$nat_gateways" ]]; then
            nat_found=1
            break
        fi
    done

    if [[ "$nat_found" -eq 1 ]]; then
        nat_status["$REGION"]="Compliant"
        nat_display="${GREEN}Available${NC}"
    else
        nat_status["$REGION"]="Non-Compliant"
        nat_display="${RED}None${NC}"
    fi

    printf "| %-14s | %-16s | %-11s |\n" "$REGION" "$shield_display" "$nat_display"
done

echo "+--------------+----------------+-------------+"
echo ""

# Step 2: Summary of Compliant vs Non-Compliant Regions
shield_compliant=0
shield_non_compliant=0
nat_compliant=0
nat_non_compliant=0

for region in "${!shield_status[@]}"; do
    if [[ "${shield_status[$region]}" == "Compliant" ]]; then
        ((shield_compliant++))
    else
        ((shield_non_compliant++))
    fi
done

for region in "${!nat_status[@]}"; do
    if [[ "${nat_status[$region]}" == "Compliant" ]]; then
        ((nat_compliant++))
    else
        ((nat_non_compliant++))
    fi
done

echo "Summary:"
echo -e "${GREEN}Compliant Shield Advanced Regions: $shield_compliant${NC}"
echo -e "${RED}Non-Compliant Shield Advanced Regions: $shield_non_compliant${NC}"
echo -e "${GREEN}Compliant NAT Gateway Regions: $nat_compliant${NC}"
echo -e "${RED}Non-Compliant NAT Gateway Regions: $nat_non_compliant${NC}"
echo ""

echo "Audit completed for all regions."
