#!/bin/bash

# Description and Criteria
description="AWS Security Groups Audit for Default Security Groups with Unrestricted Inbound Access"
criteria="This script identifies default security groups that allow unrestricted inbound traffic (0.0.0.0/0).
Any security group with unrestricted access is marked as 'Non-Compliant' (printed in red)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --filters 'Name=group-name,Values=default' --query 'SecurityGroups[*].IpPermissions[*].IpRanges'"

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
echo "| Region         | Open SG Found  |"
echo "+----------------+----------------+"

# Audit each region for security groups with unrestricted access
declare -A region_sg_count
for REGION in $regions; do
  sg_sources=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters "Name=group-name,Values=default" \
    --query 'SecurityGroups[*].IpPermissions[*].IpRanges[*].CidrIp' --output text)

  open_sg_count=0
  if echo "$sg_sources" | grep -q "0.0.0.0/0"; then
    open_sg_count=1
  fi

  region_sg_count[$REGION]=$open_sg_count
  printf "| %-14s | %-14s |\n" "$REGION" "$open_sg_count"
done
echo "+----------------+----------------+"
echo ""

# Show security groups with open access
for REGION in "${!region_sg_count[@]}"; do
  if [ "${region_sg_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"
    sg_sources=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --filters "Name=group-name,Values=default" \
      --query 'SecurityGroups[*].IpPermissions[*].IpRanges[*].CidrIp' --output text)

    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo "Inbound Traffic Sources for Default Security Group:"
    echo "$sg_sources"
    echo -e "Status: ${RED} Non-Compliant (Unrestricted Inbound Access Detected)${NC}"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions."
