#!/bin/bash

# Description and Criteria
description="AWS Audit for Excessive EC2 Security Groups"
criteria="This script checks the number of EC2 security groups in each AWS region. If the total exceeds 100, action is required to remove unnecessary or overlapping security groups."

# Command used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --query 'SecurityGroups[*].GroupId'"

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

# Table Header (only showing Total Security Groups per region)
echo "\n+----------------+-------------------------+"
echo "| Region         | Total Security Groups   |"
echo "+----------------+-------------------------+"

# Audit each region
declare -A region_sg_count

for REGION in $regions; do
  # Get all security group IDs in the region
  sg_list=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --query 'SecurityGroups[*].GroupId' --output text)

  total_sg_count=$(echo "$sg_list" | wc -w)

  region_sg_count[$REGION]=$total_sg_count

  # Highlight in red if security groups exceed 100
  if [ "$total_sg_count" -gt 100 ]; then
    printf "| %-14s | ${RED}%-23s${NC} |\n" "$REGION" "$total_sg_count"
  else
    printf "| %-14s | %-23s |\n" "$REGION" "$total_sg_count"
  fi
done
echo "+----------------+-------------------------+"
echo ""

# Show detailed audit results for regions exceeding the threshold
for REGION in "${!region_sg_count[@]}"; do
  if [ "${region_sg_count[$REGION]}" -gt 100 ]; then
    echo -e "${RED}WARNING: Region $REGION has ${region_sg_count[$REGION]} security groups, exceeding the recommended limit of 100.${NC}"
    echo "Consider removing unnecessary or overlapping security groups."
    echo ""
  fi
done

echo "Audit completed for all regions."
