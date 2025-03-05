#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instance Subnet Isolation"
criteria="This script verifies whether backend EC2 instances are provisioned within private subnets by checking the associated route tables."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].SubnetId'
  4. aws ec2 describe-route-tables --region \$REGION --filters \"Name=association.subnet-id,Values=\$SUBNET_ID\" --query 'RouteTables[*].Routes[]'"

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
echo "+----------------+----------------+"
echo "| Region         | Instances Found |"
echo "+----------------+----------------+"

# Collect instance count per region
declare -A region_instance_count

for REGION in $regions; do
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  instance_count=$(echo "$instance_ids" | wc -w)
  region_instance_count["$REGION"]=$instance_count

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+----------------+"
echo ""

# Perform detailed audit per instance
for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  for INSTANCE_ID in $instance_ids; do
    # Fetch subnet ID
    SUBNET_ID=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[*].Instances[*].SubnetId" --output text)

    if [[ -z "$SUBNET_ID" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo -e "Status: ${RED}❌ No Subnet ID Found${NC}"
      echo "--------------------------------------------------"
      continue
    fi

    # Fetch route table routes
    ROUTE_TABLES=$(aws ec2 describe-route-tables --region "$REGION" --profile "$PROFILE" \
      --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
      --query 'RouteTables[*].Routes[]' --output json)

    if echo "$ROUTE_TABLES" | grep -q '"GatewayId": "igw-'; then
      STATUS="${RED}❌ Public Subnet (Internet Gateway Found)${NC}"
    elif echo "$ROUTE_TABLES" | grep -q '"DestinationCidrBlock": "0.0.0.0/0"'; then
      STATUS="${RED}❌ Public Subnet (Open Route to Internet)${NC}"
    else
      STATUS="${GREEN}✅ Private Subnet (No Internet Exposure)${NC}"
    fi

    # Print instance audit result
    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo "Instance ID: $INSTANCE_ID"
    echo "Subnet ID: $SUBNET_ID"
    echo -e "Status: $STATUS"
    echo "--------------------------------------------------"
  done
done

echo "Audit completed for all regions."
