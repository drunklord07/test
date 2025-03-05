#!/bin/bash

# Description and Criteria
description="AWS App-Tier EC2 Instance IAM Role Audit"
criteria="This script lists all EC2 instances in each region, verifies if they belong to the app-tier based on a specific tag, 
and checks if they have an IAM instance profile assigned. 
If an app-tier instance lacks an IAM role, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-tags --region \$REGION --filters Name=resource-id,Values=\$INSTANCE_ID --query 'Tags[*].{Key:Key, Value:Value}'
  4. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn[]'"

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

# Set the tag key and value for identifying app-tier instances
TAG_NAME="app_tier_tag"
TAG_VALUE="app_tier_tag_value"

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

# Audit only regions with EC2 instances
for REGION in "${!region_instance_count[@]}"; do
  if [ "${region_instance_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text)

    while read -r instance_id; do
      echo "--------------------------------------------------"
      echo "Instance ID: $instance_id"

      # Fetch tags for the instance
      tags=$(aws ec2 describe-tags --region "$REGION" --profile "$PROFILE" \
        --filters "Name=resource-id,Values=$instance_id" \
        --query 'Tags[*].{Key:Key, Value:Value}' --output json)

      # Check if instance has no tags
      if [ "$tags" == "[]" ]; then
        echo -e "Status: ${RED} Non-Compliant (No Tags Found)${NC}"
        continue
      fi

      # Check if instance is an app-tier instance
      if echo "$tags" | grep -q "\"Key\": \"$TAG_NAME\"" && echo "$tags" | grep -q "\"Value\": \"$TAG_VALUE\""; then
        echo "Instance is tagged as an App-Tier resource."
      else
        echo -e "Status: ${RED} Non-Compliant (Incorrect Tag)${NC}"
        continue
      fi

      # Check if instance has an IAM Role
      iam_role=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn' --output text)

      if [ -z "$iam_role" ] || [ "$iam_role" == "None" ]; then
        echo -e "Status: ${RED} Non-Compliant (No IAM Role Assigned)${NC}"
      else
        echo -e "Status: ${GREEN} Compliant (IAM Role Assigned: $iam_role)${NC}"
      fi
    done <<< "$instances"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with EC2 instances."
