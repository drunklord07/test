#!/bin/bash

# Description and Criteria
description="AWS Unapproved AMI Compliance Audit"
criteria="This script checks whether EC2 instances were launched using a banned (unapproved) AMI. 
Instances using banned AMIs are marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,ImageId:ImageId}'
  3. Compare returned ImageId with banned (unapproved) AMIs."

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display description, criteria, and the command being used
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

# Define banned (unapproved) AMI IDs
BANNED_AMIS=("ami-0abcd1234abcd1234" "ami-01234abcd1234abcd")

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+-----------------+"
echo "| Region        | Total Instances |"
echo "+----------------+-----------------+"

# Loop through each region and count EC2 instances
declare -A region_instance_count
for REGION in $regions; do
  instance_count=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'length(Reservations[*].Instances[*])' --output text)

  if [ "$instance_count" == "None" ]; then
    instance_count=0
  fi

  region_instance_count[$REGION]=$instance_count
  printf "| %-14s | %-15s |\n" "$REGION" "$instance_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with instances
for REGION in "${!region_instance_count[@]}"; do
  if [ "${region_instance_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,ImageId:ImageId}' --output json)

    echo "$instances" | jq -c '.[] | .[]' | while read -r instance; do
      instance_id=$(echo "$instance" | jq -r '.InstanceId')
      image_id=$(echo "$instance" | jq -r '.ImageId')

      echo "--------------------------------------------------"
      echo "Instance ID: $instance_id"
      echo "Image ID: $image_id"

      # Check if the instance was launched from a banned AMI
      if [[ " ${BANNED_AMIS[*]} " =~ " $image_id " ]]; then
        echo -e "Status: ${RED} Non-Compliant (Banned AMI Used)${NC}"
      else
        echo -e "Status: ${GREEN} Compliant (Approved AMI)${NC}"
      fi
    done
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with EC2 instances."
