#!/bin/bash

# Description and Criteria
description="AWS Audit for VPCs without associated VPC Endpoints"
criteria="This script identifies VPCs that do not have any associated VPC endpoints in all AWS regions."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-vpcs --region \$REGION --query 'Vpcs[*].VpcId'
  3. aws ec2 describe-vpc-endpoints --region \$REGION --filters Name=vpc-id,Values=\$VPC_ID --query 'VpcEndpoints[*].VpcEndpointId'"

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
echo "| Region         | VPC Count      |"
echo "+----------------+----------------+"

# Dictionary for storing VPC counts
declare -A vpc_counts

# Audit each region
for REGION in $regions; do
  # Count VPCs
  vpcs=$(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" \
    --query 'Vpcs[*].VpcId' --output text)
  vpc_count=$(echo "$vpcs" | wc -w)
  vpc_counts[$REGION]=$vpc_count

  printf "| %-14s | %-14s |\n" "$REGION" "$vpc_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each VPC for associated VPC Endpoints
for REGION in "${!vpc_counts[@]}"; do
  if [ "${vpc_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for VPC_ID in $(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" \
      --query 'Vpcs[*].VpcId' --output text); do

      # Get VPC Endpoint count
      vpce_list=$(aws ec2 describe-vpc-endpoints --region "$REGION" --profile "$PROFILE" \
        --filters Name=vpc-id,Values="$VPC_ID" --query 'VpcEndpoints[*].VpcEndpointId' \
        --output text)

      if [ -z "$vpce_list" ]; then
        STATUS="${RED}Non-Compliant (No VPC Endpoints)${NC}"
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "VPC ID: $VPC_ID"
        echo "Status: $STATUS"
        echo "--------------------------------------------------"
      fi
    done
  fi
done

echo "Audit completed for all regions."
