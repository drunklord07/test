#!/bin/bash

# Description and Criteria
description="AWS Approved (Golden) AMI Compliance Audit"
criteria="This script checks whether EC2 instances were launched using an approved (golden) AMI. 
Instances using unapproved AMIs are marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,ImageId:ImageId}'
  3. Compare returned ImageId with pre-approved (golden) AMIs."

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

# Define approved (golden) AMI IDs
declare -A APPROVED_AMIS
APPROVED_AMIS["ami-0abcd1234abcd1234"]=1
APPROVED_AMIS["ami-01234abcd1234abcd"]=1

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

    # Fetch instance details (InstanceId, ImageId) and process in batches of 50
    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].[InstanceId, ImageId]' --output text)

    # Initialize counters
    compliant_count=0
    non_compliant_count=0

    while IFS=$'\t' read -r instance_id image_id; do
      if [[ -z "$instance_id" || -z "$image_id" ]]; then
        continue
      fi

      # Check if AMI is approved
      if [[ -n "${APPROVED_AMIS[$image_id]}" ]]; then
        ((compliant_count++))
      else
        ((non_compliant_count++))
      fi
    done <<< "$instances"

    # Display summary per region
    echo "--------------------------------------------------"
    echo "Total Instances in $REGION: ${region_instance_count[$REGION]}"
    echo -e "Compliant (Golden AMI Used): ${GREEN}$compliant_count${NC}"
    echo -e "Non-Compliant (Unapproved AMI): ${RED}$non_compliant_count${NC}"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with EC2 instances."
