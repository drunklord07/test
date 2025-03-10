#!/bin/bash

# Description and Criteria
description="AWS Audit for Running EC2 Instances & Launch Age"
criteria="This script identifies running EC2 instances and verifies their launch time to determine if they have been running for more than 180 days."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --filters Name=instance-state-name,Values=running --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].LaunchTime'"

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
echo "| Region         | Running Instances |"
echo "+----------------+----------------+"

# Collect instance count per region
declare -A region_instance_count

for REGION in $regions; do
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  instance_count=$(echo "$instance_ids" | wc -w)
  region_instance_count["$REGION"]=$instance_count

  printf "| %-14s | %-18s |\n" "$REGION" "$instance_count"
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
    --filters Name=instance-state-name,Values=running \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  for INSTANCE_ID in $instance_ids; do
    # Fetch instance launch time
    LAUNCH_TIME=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[*].Instances[*].LaunchTime" --output text)

    # Convert LAUNCH_TIME to Unix timestamp
    LAUNCH_EPOCH=$(date -d "$LAUNCH_TIME" +%s)
    CURRENT_EPOCH=$(date +%s)
    AGE_DAYS=$(( (CURRENT_EPOCH - LAUNCH_EPOCH) / 86400 ))

    # Determine status
    if [[ $AGE_DAYS -le 180 ]]; then
      STATUS="${GREEN}✅ Instance is within 180 days${NC}"
    else
      STATUS="${RED}❌ Instance is older than 180 days (Restart Recommended)${NC}"
    fi

    # Print instance audit result
    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo "Instance ID: $INSTANCE_ID"
    echo "Launch Time: $LAUNCH_TIME"
    echo "Instance Age: $AGE_DAYS days"
    echo -e "Status: $STATUS"
    echo "--------------------------------------------------"
  done
done

echo "Audit completed for all regions."
