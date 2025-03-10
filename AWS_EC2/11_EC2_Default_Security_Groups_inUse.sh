#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances Using Default Security Groups"
criteria="This script identifies Amazon EC2 instances that are associated with the default security group in each AWS region.
Instances using the default security group are marked as 'Non-Compliant' (printed in red)."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --filters 'Name=instance.group-name,Values=default' --query 'Reservations[*].Instances[*].InstanceId'"

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

# Audit each region for instances using the default security group
declare -A region_instance_count
for REGION in $regions; do
  instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --filters "Name=instance.group-name,Values=default" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count[$REGION]=$instance_count

  printf "| %-14s | %-14s |\n" "$REGION" "$instance_count"
done
echo "+----------------+----------------+"
echo ""

# Show instances using the default security group
for REGION in "${!region_instance_count[@]}"; do
  if [ "${region_instance_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"
    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --filters "Name=instance.group-name,Values=default" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text)

    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo "Instances Using Default Security Group:"
    echo "$instances"
    echo -e "Status: ${RED} Non-Compliant (Instances using Default Security Group)${NC}"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions."
