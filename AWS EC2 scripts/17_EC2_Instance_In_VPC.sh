#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2-Classic Instances"
criteria="If the account supports both EC2 and VPC platforms, check if any instances are running in EC2-Classic. Instances without a VPC ID are in EC2-Classic."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-account-attributes --attribute-names supported-platforms
  2. aws ec2 describe-instances --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[*].Instances[*].VpcId'"

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

# Check supported EC2 platforms
platforms=$(aws ec2 describe-account-attributes --profile "$PROFILE" \
  --attribute-names supported-platforms \
  --query 'AccountAttributes[0].AttributeValues[*].AttributeValue' --output text)

echo "--------------------------------------------------"
echo "Supported EC2 Platforms: $platforms"
echo "--------------------------------------------------"

# If only VPC is supported, exit
if [[ "$platforms" == "VPC" ]]; then
  echo -e "${GREEN}All instances are running in EC2-VPC.${NC}"
  exit 0
fi

echo "Account supports both EC2 and VPC. Checking for EC2-Classic instances..."
echo ""

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Initialize EC2-Classic instance count
classic_count=0

# Table Header
echo "\n+----------------+----------------+-------------------------+"
echo "| Region         | Classic Count  | Instance IDs            |"
echo "+----------------+----------------+-------------------------+"

# Audit each region
for REGION in $regions; do
  # Get all instance IDs
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  ec2_classic_instances=0
  classic_instance_list=""

  # Check each instance for EC2-Classic
  for instance in $instance_ids; do
    vpc_id=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --instance-ids "$instance" --query 'Reservations[*].Instances[*].VpcId' --output text)

    if [ -z "$vpc_id" ]; then
      ec2_classic_instances=$((ec2_classic_instances + 1))
      classic_count=$((classic_count + 1))
      classic_instance_list+="$instance, "
    fi
  done

  # Remove trailing comma and space
  classic_instance_list=${classic_instance_list%, }

  # Print results per region
  printf "| %-14s | %-14s | %-23s |\n" "$REGION" "$ec2_classic_instances" "$classic_instance_list"
done
echo "+----------------+----------------+-------------------------+"
echo ""

# Display results
echo "--------------------------------------------------"
echo -e "Total EC2-Classic Instances Across All Regions: ${PURPLE}$classic_count${NC}"
echo "--------------------------------------------------"

# Check if action is needed
if [ "$classic_count" -gt 0 ]; then
  echo -e "${RED}ALERT: Some EC2 instances are still running on EC2-Classic.${NC}"
  echo "Action Required: Migrate these instances to EC2-VPC before EC2-Classic is fully deprecated."
else
  echo -e "${GREEN}COMPLIANT: No instances are running on EC2-Classic.${NC}"
fi

echo "Audit completed for all regions."
