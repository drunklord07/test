#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances with Public or Elastic IP Addresses"
criteria="This script identifies Amazon EC2 instances that are associated with a public or Elastic IP address. 
Instances with a public IP are marked as 'Non-Compliant' (printed in red)."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Association.IpOwnerId[] | []'"

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
echo "\n+----------------+----------------+"
echo "| Region         | Instances Found |"
echo "+----------------+----------------+"

# Audit each region for EC2 instances
for REGION in $regions; do
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  instance_count=$(echo "$instance_ids" | wc -w)

  printf "| %-14s | %-14s |\n" "$REGION" "$instance_count"
done
echo "+----------------+----------------+"
echo ""

# Check each instance for public or Elastic IPs
for REGION in $regions; do
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  if [[ -z "$instance_ids" ]]; then
    continue
  fi

  echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

  for INSTANCE_ID in $instance_ids; do
    ip_owner=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[*].Instances[*].NetworkInterfaces[*].Association.IpOwnerId[] | []' \
      --output text)

    if [[ "$ip_owner" == "amazon" || "$ip_owner" =~ ^[0-9]+$ ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo -e "Status: ${RED} Non-Compliant (Public or Elastic IP Detected)${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
