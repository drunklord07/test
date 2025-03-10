#!/bin/bash

# Description and Criteria
description="AWS Audit for Unrestricted Inbound Rules in Network ACLs (NACLs)"
criteria="This script identifies NACLs that have an ALLOW rule without a defined 'PortRange' attribute, meaning all inbound traffic is allowed, making them non-compliant."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-network-acls --region \$REGION --query 'NetworkAcls[*].NetworkAclId'
  3. aws ec2 describe-network-acls --region \$REGION --network-acl-ids \$NACL_ID --query 'NetworkAcls[*].Entries'"

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
  # Count NACLs
  nacls=$(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
    --query 'NetworkAcls[*].NetworkAclId' --output text)
  nacl_count=$(echo "$nacls" | wc -w)
  nacl_counts[$REGION]=$nacl_count

  printf "| %-14s | %-14s |\n" "$REGION" "$nacl_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each NACL for compliance
for REGION in "${!nacl_counts[@]}"; do
  if [ "${nacl_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for NACL_ID in $(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
      --query 'NetworkAcls[*].NetworkAclId' --output text); do

      # Get inbound ALLOW rules without PortRange
      nacl_entries=$(aws ec2 describe-network-acls --region "$REGION" --profile "$PROFILE" \
        --network-acl-ids "$NACL_ID" --query 'NetworkAcls[*].Entries[?(RuleAction==`allow`) && (Egress==`false`) && !not_null(PortRange)]' \
        --output json)

      # Check for non-compliant rules
      echo "$nacl_entries" | grep -q '"CidrBlock": "0.0.0.0/0"'

      if [ $? -eq 0 ]; then
        STATUS="${RED}Non-Compliant (All Ports Open to 0.0.0.0/0)${NC}"
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "NACL ID: $NACL_ID"
        echo "Status: $STATUS"
        echo "--------------------------------------------------"
      fi
    done
  fi
done

echo "Audit completed for all regions."
