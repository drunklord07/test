#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Groups Allowing Unrestricted FTP Access (TCP 20, 21)"
criteria="This script checks if security groups allow inbound FTP traffic on TCP ports 20 and 21 from 0.0.0.0/0."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --filters Name=ip-permission.from-port,Values=20,21 Name=ip-permission.to-port,Values=20,21 Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].GroupId' --output text"

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
echo "Region         | Security Groups Allowing FTP"
echo "+----------------+--------------------------------------+"

# Dictionary to store non-compliant security groups
declare -A non_compliant_sgs

# Audit each region
for REGION in $regions; do
  # Get security groups allowing unrestricted FTP traffic
  sg_ids=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters Name=ip-permission.from-port,Values=20,21 Name=ip-permission.to-port,Values=20,21 \
              Name=ip-permission.cidr,Values="0.0.0.0/0" \
    --query 'SecurityGroups[*].GroupId' --output text)

  # Count total non-compliant security groups in the region
  if [ -n "$sg_ids" ]; then
    count=$(echo "$sg_ids" | wc -w)
    non_compliant_sgs["$REGION"]="$sg_ids"
    printf "| %-14s | ${RED}%-36s${NC} |\n" "$REGION" "$count SG(s) found"
  else
    printf "| %-14s | ${GREEN}None detected${NC}                 |\n" "$REGION"
  fi
done

echo "+----------------+--------------------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_sgs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Security Groups:${NC}"
  echo "---------------------------------------------------"

  for region in "${!non_compliant_sgs[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Security Group IDs:"
    echo -e "${non_compliant_sgs[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No non-compliant security groups detected.${NC}"
fi

echo "Audit completed for all regions."
