#!/bin/bash

# Description and Criteria
description="AWS Security Groups Audit for Unrestricted Redis Access"
criteria="This script identifies security groups that allow unrestricted inbound access on TCP port 6379 (Redis).
Security groups with unrestricted access are marked as 'Non-Compliant' (printed in red)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --filters 'Name=ip-permission.from-port,Values=6379' 'Name=ip-permission.to-port,Values=6379' 'Name=ip-permission.cidr,Values=0.0.0.0/0' --query 'SecurityGroups[*].GroupId'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display description, criteria, and the command being used
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
echo "| Region         | Open SG Count  |"
echo "+----------------+----------------+"

# Audit each region for security groups allowing unrestricted access on port 6379
declare -A region_sg_count
for REGION in $regions; do
  sg_list=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters "Name=ip-permission.from-port,Values=6379" "Name=ip-permission.to-port,Values=6379" "Name=ip-permission.cidr,Values=0.0.0.0/0" \
    --query 'SecurityGroups[*].GroupId' --output text)

  sg_count=$(echo "$sg_list" | wc -w)

  if [ -z "$sg_list" ] || [ "$sg_list" == "None" ]; then
    sg_count=0
  fi

  region_sg_count[$REGION]=$sg_count
  printf "| %-14s | %-14s |\n" "$REGION" "$sg_count"
done
echo "+----------------+----------------+"
echo ""

# Show security groups with open access
for REGION in "${!region_sg_count[@]}"; do
  if [ "${region_sg_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"
    sg_list=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --filters "Name=ip-permission.from-port,Values=6379" "Name=ip-permission.to-port,Values=6379" "Name=ip-permission.cidr,Values=0.0.0.0/0" \
      --query 'SecurityGroups[*].GroupId' --output text)

    for SG_ID in $sg_list; do
      echo "--------------------------------------------------"
      echo "Security Group ID: $SG_ID"
      echo -e "Status: ${RED} Non-Compliant (Unrestricted Redis Access)${NC}"
    done
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions."
