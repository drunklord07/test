#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances Without IAM Roles"
criteria="This script checks if any EC2 instances in all AWS regions are missing an associated IAM role."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId' --output text
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn[]' --output text"

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
echo "Region         | EC2 Instances Without IAM Roles"
echo "+--------------+--------------------------------+"

# Dictionary to store non-compliant instances
declare -A non_compliant_instances

# Audit each region
for REGION in $regions; do
  # Get all EC2 instance IDs
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  if [[ -z "$instance_ids" ]]; then
    printf "| %-14s | ${GREEN}No instances found${NC}           |\n" "$REGION"
    continue
  fi

  non_compliant=()
  for INSTANCE_ID in $instance_ids; do
    # Check if instance has an IAM role
    iam_role=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --instance-ids "$INSTANCE_ID" \
      --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn[]' --output text)

    if [[ -z "$iam_role" ]]; then
      non_compliant+=("$INSTANCE_ID")
    fi
  done

  if [[ ${#non_compliant[@]} -gt 0 ]]; then
    non_compliant_instances["$REGION"]="${non_compliant[*]}"
    printf "| %-14s | ${RED}%-24s${NC} |\n" "$REGION" "$(echo "${non_compliant[*]}" | wc -w) Instance(s) missing IAM role"
  else
    printf "| %-14s | ${GREEN}All instances have IAM roles${NC} |\n" "$REGION"
  fi
done

echo "+--------------+--------------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_instances[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant EC2 Instances (No IAM Role):${NC}"
  echo "------------------------------------------------------------"

  for region in "${!non_compliant_instances[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Instances Without IAM Roles:"
    echo -e "${non_compliant_instances[$region]}" | awk '{print " - " $0}'
    echo "------------------------------------------------------------"
  done
else
  echo -e "${GREEN}All EC2 instances have IAM roles.${NC}"
fi

echo "Audit completed for all regions."
