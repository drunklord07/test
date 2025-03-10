#!/bin/bash

# Description and Criteria
description="AWS Audit for Ineffective or Misconfigured Network ACL (NACL) DENY Rules"
criteria="This script identifies Network ACLs (NACLs) with DENY rules that are ineffective or partially ineffective due to conflicting higher priority ALLOW rules."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-network-acls --region \$REGION --query 'NetworkAcls[*].NetworkAclId'
  3. aws ec2 describe-network-acls --region \$REGION --network-acl-ids \$NACL_ID --query 'NetworkAcls[*].Entries[?(@.Egress==false)]'
  4. aws ec2 describe-network-acls --region \$REGION --network-acl-ids \$NACL_ID --query 'NetworkAcls[*].Entries[?(@.Egress==true)]'"

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
echo "| Region         | NACL Count     |"
echo "+----------------+----------------+"

# Dictionary for storing NACL counts
declare -A nacl_counts

# Audit each region
for REGION in $regions; do
  nacls=$(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
    --query 'NetworkAcls[*].NetworkAclId' --output text)

  nacl_count=$(echo "$nacls" | wc -w)
  nacl_counts[$REGION]=$nacl_count

  printf "| %-14s | %-14s |\n" "$REGION" "$nacl_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each NACL for ineffective or redundant DENY rules
for REGION in "${!nacl_counts[@]}"; do
  if [ "${nacl_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for NACL_ID in $(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
      --query 'NetworkAcls[*].NetworkAclId' --output text); do

      # Fetch inbound and outbound rules
      inbound_rules=$(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
        --network-acl-ids "$NACL_ID" --query 'NetworkAcls[*].Entries[?(@.Egress==false)]' --output text)

      outbound_rules=$(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
        --network-acl-ids "$NACL_ID" --query 'NetworkAcls[*].Entries[?(@.Egress==true)]' --output text)

      # Process inbound rules
      if [ -n "$inbound_rules" ]; then
        echo -e "${CYAN}Checking inbound rules for NACL: $NACL_ID${NC}"

        while read -r rule_number protocol port_range cidr rule_action; do
          if [ "$rule_action" == "DENY" ]; then
            # Check if there's a higher priority (lower rule number) ALLOW rule with the same criteria
            higher_allow=$(echo "$inbound_rules" | awk -v rule="$rule_number" -v port="$port_range" -v cidr="$cidr" \
              '$1 < rule && $4 == "ALLOW" && $3 == port && $5 == cidr {print $1}')

            if [ -n "$higher_allow" ]; then
              STATUS="${RED}Non-Compliant (Ineffective DENY Rule)${NC}"
              echo "--------------------------------------------------"
              echo "Region: $REGION"
              echo "NACL ID: $NACL_ID"
              echo "Rule Number: $rule_number"
              echo "Protocol: $protocol"
              echo "Port Range: $port_range"
              echo "CIDR Block: $cidr"
              echo "Rule Action: $rule_action"
              echo "Status: $STATUS"
              echo "--------------------------------------------------"
            fi
          fi
        done <<< "$inbound_rules"
      fi

      # Process outbound rules
      if [ -n "$outbound_rules" ]; then
        echo -e "${CYAN}Checking outbound rules for NACL: $NACL_ID${NC}"

        while read -r rule_number protocol port_range cidr rule_action; do
          if [ "$rule_action" == "DENY" ]; then
            # Check if there's a higher priority (lower rule number) ALLOW rule with the same criteria
            higher_allow=$(echo "$outbound_rules" | awk -v rule="$rule_number" -v port="$port_range" -v cidr="$cidr" \
              '$1 < rule && $4 == "ALLOW" && $3 == port && $5 == cidr {print $1}')

            if [ -n "$higher_allow" ]; then
              STATUS="${RED}Non-Compliant (Ineffective DENY Rule)${NC}"
              echo "--------------------------------------------------"
              echo "Region: $REGION"
              echo "NACL ID: $NACL_ID"
              echo "Rule Number: $rule_number"
              echo "Protocol: $protocol"
              echo "Port Range: $port_range"
              echo "CIDR Block: $cidr"
              echo "Rule Action: $rule_action"
              echo "Status: $STATUS"
              echo "--------------------------------------------------"
            fi
          fi
        done <<< "$outbound_rules"
      fi
    done
  fi
done

echo "Audit completed for all regions."
