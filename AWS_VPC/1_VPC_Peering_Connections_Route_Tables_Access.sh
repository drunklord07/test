#!/bin/bash

# Description and Criteria
description="AWS Audit for Overly Permissive VPC Peering Route Tables"
criteria="This script identifies VPC peering connections with overly permissive routing policies.
Any route that allows access to broad CIDR blocks (e.g., /16 or larger) is flagged as 'Non-Compliant'."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-vpc-peering-connections --region \$REGION --filters Name=status-code,Values=active --query 'VpcPeeringConnections[*].VpcPeeringConnectionId'
  3. aws ec2 describe-route-tables --region \$REGION --filters Name=route.vpc-peering-connection-id,Values=\$PEERING_ID --query 'RouteTables[*].Routes[*].[DestinationCidrBlock,VpcPeeringConnectionId]'"

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
echo "| Region         | VPC Peerings   |"
echo "+----------------+----------------+"

# Dictionary for storing VPC peering connection counts
declare -A vpc_counts

# Audit each region
for REGION in $regions; do
  peering_connections=$(aws ec2 describe-vpc-peering-connections --region "$REGION" --profile "$PROFILE" \
    --filters Name=status-code,Values=active --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text)

  peering_count=$(echo "$peering_connections" | wc -w)
  vpc_counts[$REGION]=$peering_count

  printf "| %-14s | %-14s |\n" "$REGION" "$peering_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each VPC peering connection for overly permissive routes
for REGION in "${!vpc_counts[@]}"; do
  if [ "${vpc_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for PEERING_ID in $(aws ec2 describe-vpc-peering-connections --region "$REGION" --profile "$PROFILE" \
      --filters Name=status-code,Values=active --query 'VpcPeeringConnections[*].VpcPeeringConnectionId' --output text); do

      # Get associated route tables and filter routes
      routes=$(aws ec2 describe-route-tables --region "$REGION" --profile "$PROFILE" \
        --filters "Name=route.vpc-peering-connection-id,Values=$PEERING_ID" \
        --query 'RouteTables[*].Routes[*].[DestinationCidrBlock,VpcPeeringConnectionId]' --output text)

      if [ -z "$routes" ]; then
        continue
      fi

      # Check for overly permissive routes
      while read -r dest_cidr peering_id; do
        if [[ -n "$peering_id" && "$peering_id" == "$PEERING_ID" ]]; then
          cidr_suffix=$(echo "$dest_cidr" | awk -F'/' '{print $2}')
          if [[ "$cidr_suffix" -le 16 ]]; then
            STATUS="${RED}Non-Compliant (Overly Permissive Route)${NC}"

            # Print audit details
            echo "--------------------------------------------------"
            echo "Region: $REGION"
            echo "VPC Peering Connection: $PEERING_ID"
            echo "Destination CIDR Block: $dest_cidr"
            echo "Status: $STATUS"
            echo "--------------------------------------------------"
          fi
        fi
      done <<< "$routes"
    done
  fi
done

echo "Audit completed for all regions."
