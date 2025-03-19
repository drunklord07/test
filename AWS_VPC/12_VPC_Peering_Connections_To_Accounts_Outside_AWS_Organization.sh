#!/bin/bash

# Description and Criteria
description="AWS Audit for Cross-Account VPC Peering Connections"
criteria="This script identifies VPC peering connections between AWS accounts inside and outside your AWS Organization."

# Commands used
command_used="Commands Used:
  1. aws organizations list-accounts --query 'Accounts[*].Id' --output text
  2. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  3. aws ec2 describe-vpc-peering-connections --region REGION --filters Name=status-code,Values=active
  4. aws ec2 describe-vpc-peering-connections --region REGION --filters Name=vpc-peering-connection-id,Values=PEERING_ID"

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

# Get list of AWS Organization accounts
org_accounts=$(aws organizations list-accounts --profile "$PROFILE" --query 'Accounts[*].Id' --output text)
echo -e "${CYAN}Organization Accounts: $org_accounts${NC}"
echo "====================================================================="

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+----------------+"
echo "| Region         | Peering Count  |"
echo "+----------------+----------------+"

# Dictionary for storing peering connection counts
declare -A peering_counts

# Gather VPC peering connection counts per region
for REGION in $regions; do
  peerings=$(aws ec2 describe-vpc-peering-connections --region "$REGION" --profile "$PROFILE" \
    --filters Name=status-code,Values=active \
    --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text)

  peering_count=$(echo "$peerings" | wc -w)
  peering_counts["$REGION"]=$peering_count

  printf "| %-14s | %-14s |\n" "$REGION" "$peering_count"
done
echo "+----------------+----------------+"
echo ""

# Start audit for non-compliant connections
non_compliant_found=0

for REGION in "${!peering_counts[@]}"; do
  if [ "${peering_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for PEERING_ID in $(aws ec2 describe-vpc-peering-connections --region "$REGION" --profile "$PROFILE" \
      --filters Name=status-code,Values=active \
      --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text); do

      # Get Requester and Accepter account IDs
      peering_info=$(aws ec2 describe-vpc-peering-connections --region "$REGION" --profile "$PROFILE" \
        --filters Name=vpc-peering-connection-id,Values=$PEERING_ID \
        --query 'VpcPeeringConnections[*].[RequesterVpcInfo.OwnerId, AccepterVpcInfo.OwnerId]' --output text)

      requester_id=$(echo "$peering_info" | awk '{print $1}')
      accepter_id=$(echo "$peering_info" | awk '{print $2}')

      # Check if both IDs belong to the AWS Organization
      if [[ " $org_accounts " != *"$requester_id"* || " $org_accounts " != *"$accepter_id"* ]]; then
        non_compliant_found=1
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "VPC Peering ID: $PEERING_ID"
        echo "Requester ID: $requester_id"
        echo "Accepter ID: $accepter_id"
        echo -e "Status: ${RED}Non-Compliant (Cross-Account Peering)${NC}"
        echo "--------------------------------------------------"
      else
        echo -e "${GREEN}Region: $REGION | VPC Peering ID: $PEERING_ID | Status: Compliant${NC}"
      fi
    done
  fi
done

if [[ "$non_compliant_found" -eq 0 ]]; then
  echo -e "${GREEN}No non-compliant VPC peering connections found.${NC}"
fi

echo "Audit completed for all regions."
