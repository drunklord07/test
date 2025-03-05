#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instance Count Across All Regions"
criteria="If the total number of Amazon EC2 instances exceeds 50 across all AWS regions, action is required to limit the number of instances."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId' --output text"

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

# Initialize total instance count
total_instances=0

# Table Header
echo "\n+----------------+----------------+"
echo "| Region         | Instance Count |"
echo "+----------------+----------------+"

# Audit each region for EC2 instances
for REGION in $regions; do
  instance_count=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text | wc -w)

  printf "| %-14s | %-14s |\n" "$REGION" "$instance_count"

  # Update total instance count
  total_instances=$((total_instances + instance_count))
done
echo "+----------------+----------------+"
echo ""

# Display the total count
echo "--------------------------------------------------"
echo -e "Total EC2 Instances Across All Regions: ${PURPLE}$total_instances${NC}"
echo "Recommended Threshold: 50"
echo "--------------------------------------------------"

# Check if action is needed
if [ "$total_instances" -gt 50 ]; then
  echo -e "${RED}ALERT: The total number of EC2 instances exceeds the recommended threshold (50).${NC}"
  echo "Action Required: Consider creating an AWS Support case to limit the number of instances based on workload requirements."
else
  echo -e "${GREEN}COMPLIANT: The total number of EC2 instances is within the recommended threshold.${NC}"
fi

echo "Audit completed for all regions."
