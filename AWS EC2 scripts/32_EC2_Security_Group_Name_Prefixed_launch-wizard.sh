#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances Using 'launch-wizard' Security Groups"
criteria="This script checks for EC2 instances that are associated with security groups prefixed with 'launch-wizard-*' in each AWS region."

# Command used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --filters \"Name=instance.group-name,Values=launch-wizard-*\" --query 'Reservations[*].Instances[*].InstanceId'"

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
echo "\nRegion         | EC2 Instances Found       "
echo "+----------------+---------------------------+"

# Dictionary to store non-compliant instances
declare -A non_compliant_instances

# Audit each region
for REGION in $regions; do
  # Get EC2 instance IDs using "launch-wizard" security groups
  instance_list=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --filters "Name=instance.group-name,Values=launch-wizard-*" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  # Count instances found
  instance_count=$(echo "$instance_list" | wc -w)

  if [ "$instance_count" -gt 0 ]; then
    printf "| %-14s | ${RED}%-25s${NC} |\n" "$REGION" "$instance_count instance(s) found"
    non_compliant_instances["$REGION"]="$instance_list"
  else
    printf "| %-14s | ${GREEN}None detected${NC}             |\n" "$REGION"
  fi
done

echo "+----------------+---------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_instances[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant EC2 Instances:${NC}"
  echo "---------------------------------------------------"

  for region in "${!non_compliant_instances[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Instance IDs:"
    echo "${non_compliant_instances[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No non-compliant EC2 instances detected.${NC}"
fi

echo "Audit completed for all regions."
