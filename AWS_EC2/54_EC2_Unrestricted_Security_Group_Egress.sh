#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Groups Allowing Unrestricted Outbound Traffic"
criteria="This script checks if any EC2 security groups allow unrestricted outbound access (0.0.0.0/0 or ::/0)."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --query 'SecurityGroups[*].GroupId' --output text
  3. aws ec2 describe-security-groups --region \$REGION --group-ids \$SG_ID --query 'SecurityGroups[*].IpPermissionsEgress[]'"

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
echo "Region         | Security Groups with Unrestricted Outbound Access"
echo "+----------------+----------------------------------+"

# Dictionary to store non-compliant security groups
declare -A non_compliant_sgs

# Audit each region
for REGION in $regions; do
  # Get all security groups in the region
  sg_ids=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --query 'SecurityGroups[*].GroupId' --output text)

  if [[ -z "$sg_ids" ]]; then
    continue
  fi

  unrestricted_sgs=()
  for SG_ID in $sg_ids; do
    # Check egress rules
    egress_rules=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --group-ids "$SG_ID" --query 'SecurityGroups[*].IpPermissionsEgress[]' --output json)

    if echo "$egress_rules" | grep -q '"CidrIp": "0.0.0.0/0"' || echo "$egress_rules" | grep -q '"CidrIpv6": "::/0"'; then
      unrestricted_sgs+=("$SG_ID")
    fi
  done

  if [[ ${#unrestricted_sgs[@]} -gt 0 ]]; then
    non_compliant_sgs["$REGION"]="${unrestricted_sgs[*]}"
    printf "| %-14s | ${RED}%-30s${NC} |\n" "$REGION" "$(echo "${unrestricted_sgs[*]}" | wc -w) SG(s) found"
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
    echo "Security Group IDs:"
    echo -e "${non_compliant_sgs[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No non-compliant security groups detected.${NC}"
fi

echo "Audit completed for all regions."
-