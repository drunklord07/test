#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Groups Allowing Unrestricted MongoDB Access"
criteria="This script checks if any EC2 security groups allow inbound MongoDB (TCP port 27017) traffic from 0.0.0.0/0 or ::/0."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --filters Name=ip-permission.from-port,Values=27017 Name=ip-permission.to-port,Values=27017 Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].GroupName' --output text
  3. aws ec2 describe-security-groups --region \$REGION --filters Name=ip-permission.from-port,Values=27017 Name=ip-permission.to-port,Values=27017 Name=ip-permission.ipv6-cidr,Values='::/0' --query 'SecurityGroups[*].GroupName' --output text"

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
echo "Region         | Unrestricted MongoDB Security Groups"
echo "+----------------+----------------------------------+"

# Dictionary to store non-compliant security groups
declare -A non_compliant_sgs

# Audit each region
for REGION in $regions; do
  # Get security group names allowing unrestricted MongoDB access (IPv4)
  sg_names_ipv4=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters Name=ip-permission.from-port,Values=27017 Name=ip-permission.to-port,Values=27017 Name=ip-permission.cidr,Values='0.0.0.0/0' \
    --query 'SecurityGroups[*].GroupName' --output text)

  # Get security group names allowing unrestricted MongoDB access (IPv6)
  sg_names_ipv6=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters Name=ip-permission.from-port,Values=27017 Name=ip-permission.to-port,Values=27017 Name=ip-permission.ipv6-cidr,Values='::/0' \
    --query 'SecurityGroups[*].GroupName' --output text)

  # Combine results
  sg_names=$(echo -e "$sg_names_ipv4\n$sg_names_ipv6" | sort -u | sed '/^$/d')

  if [[ -n "$sg_names" ]]; then
    non_compliant_sgs["$REGION"]="$sg_names"
    printf "| %-14s | ${RED}%-30s${NC} |\n" "$REGION" "$(echo "$sg_names" | wc -l) SG(s) found"
  else
    printf "| %-14s | ${GREEN}None detected${NC}                   |\n" "$REGION"
  fi
done

echo "+----------------+----------------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_sgs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Security Groups:${NC}"
  echo "---------------------------------------------------"

  for region in "${!non_compliant_sgs[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Security Group Names:"
    echo -e "${non_compliant_sgs[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No non-compliant security groups detected.${NC}"
fi

echo "Audit completed for all regions."
