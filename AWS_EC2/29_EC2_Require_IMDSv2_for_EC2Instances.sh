#!/bin/bash

# Description and Criteria
description="AWS Audit for Instance Metadata Service (IMDS) Version Enforcement"
criteria="This script checks whether EC2 instances enforce IMDSv2 (Instance Metadata Service Version 2)."

# Command used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].MetadataOptions.HttpTokens'"

# Color codes
GREEN='\033[0;32m'
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

# Table Header (only Total Instances per region)
echo "\n+----------------+----------------+"
echo "| Region         | Total Instances |"
echo "+----------------+----------------+"

# Audit each region
declare -A region_total_instances

for REGION in $regions; do
  # Get all EC2 instance IDs in the region
  instance_list=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  total_instance_count=$(echo "$instance_list" | wc -w)

  region_total_instances[$REGION]=$total_instance_count

  printf "| %-14s | %-14s |\n" "$REGION" "$total_instance_count"
done
echo "+----------------+----------------+"
echo ""

# Show detailed audit results for each region
for REGION in "${!region_total_instances[@]}"; do
  if [ "${region_total_instances[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    instance_list=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text)

    for INSTANCE_ID in $instance_list; do
      imds_version=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
        --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].MetadataOptions.HttpTokens' --output text)

      if [ "$imds_version" == "optional" ]; then
        STATUS="IMDSv1 Allowed"
      else
        STATUS="IMDSv2 Enforced"
      fi

      # Print audit details
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo "IMDS Version: $imds_version"
      echo "Status: $STATUS"
      echo "--------------------------------------------------"
    done
  fi
done

echo "Audit completed for all regions."
