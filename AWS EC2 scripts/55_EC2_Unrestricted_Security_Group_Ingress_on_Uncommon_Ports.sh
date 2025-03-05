#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Groups Allowing Unrestricted Access on Uncommon Ports"
criteria="This script checks if any EC2 security groups allow unrestricted inbound access (0.0.0.0/0 or ::/0) and detects open ports that are not commonly used for public services."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --filters Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].GroupId' --output text
  3. aws ec2 describe-security-groups --region \$REGION --filters Name=ip-permission.ipv6-cidr,Values='::/0' --query 'SecurityGroups[*].GroupId' --output text
  4. aws ec2 describe-security-groups --region \$REGION --group-ids \$SG_ID --query 'SecurityGroups[*].IpPermissions[]'"

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

# Define common ports
declare -A common_ports=(
  [22]=SSH [80]=HTTP [443]=HTTPS [3389]=RDP [5432]=PostgreSQL
  [25]=SMTP [53]=DNS [135]=RPC [137]=SMB [138]=SMB [139]=SMB
  [445]=SMB [1521]=Oracle [3306]=MySQL [1433]=SQLServer [993]=IMAP
  [465]=SMTP [587]=SMTP
)

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Security Groups with Unrestricted Uncommon Ports"
echo "+--------------+----------------------------------+"

# Dictionary to store non-compliant security groups
declare -A non_compliant_sgs

# Audit each region
for REGION in $regions; do
  # Get all security groups allowing unrestricted access (IPv4)
  sg_ids_ipv4=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters Name=ip-permission.cidr,Values='0.0.0.0/0' --query 'SecurityGroups[*].GroupId' --output text)

  # Get all security groups allowing unrestricted access (IPv6)
  sg_ids_ipv6=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --filters Name=ip-permission.ipv6-cidr,Values='::/0' --query 'SecurityGroups[*].GroupId' --output text)

  # Merge both lists and remove duplicates
  all_sg_ids=$(echo -e "$sg_ids_ipv4\n$sg_ids_ipv6" | sort -u)

  if [[ -z "$all_sg_ids" ]]; then
    continue
  fi

  unrestricted_sgs=()
  for SG_ID in $all_sg_ids; do
    # Get ingress rules
    ingress_rules=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --group-ids "$SG_ID" --query 'SecurityGroups[*].IpPermissions[]' --output json)

    uncommon_ports=()
    while read -r port; do
      if [[ -n "$port" && -z "${common_ports[$port]}" ]]; then
        uncommon_ports+=("$port")
      fi
    done < <(echo "$ingress_rules" | jq -r '.[].FromPort' 2>/dev/null | sort -u)

    if [[ ${#uncommon_ports[@]} -gt 0 ]]; then
      unrestricted_sgs+=("$SG_ID (Uncommon ports: ${uncommon_ports[*]})")
    else
      unrestricted_sgs+=("$SG_ID")
    fi
  done

  if [[ ${#unrestricted_sgs[@]} -gt 0 ]]; then
    non_compliant_sgs["$REGION"]="${unrestricted_sgs[*]}"
    printf "| %-12s | ${RED}%-30s${NC} |\n" "$REGION" "$(echo "${unrestricted_sgs[*]}" | wc -w) SG(s) found"
  else
    printf "| %-12s | ${GREEN}None detected${NC}                   |\n" "$REGION"
  fi
done

echo "+--------------+----------------------------------+"
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
