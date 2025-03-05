#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances Managed by Auto Scaling Groups (ASG)"
criteria="This script identifies EC2 instances that are not currently part of an Auto Scaling Group (ASG).
Instances not associated with an ASG are marked as 'Non-Compliant'."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws autoscaling describe-auto-scaling-instances --region \$REGION --query 'AutoScalingInstances[*].InstanceId'"

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
echo "\n+----------------+----------------+----------------+"
echo "| Region         | Total Instances | ASG Instances  |"
echo "+----------------+----------------+----------------+"

# Audit each region
declare -A region_total_instances
declare -A region_asg_instances

for REGION in $regions; do
  # Get all EC2 instances in the region
  ec2_instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  # Get EC2 instances that are part of an ASG
  asg_instances=$(aws autoscaling describe-auto-scaling-instances --region "$REGION" --profile "$PROFILE" \
    --query 'AutoScalingInstances[*].InstanceId' --output text)

  total_instance_count=$(echo "$ec2_instances" | wc -w)
  asg_instance_count=$(echo "$asg_instances" | wc -w)

  region_total_instances[$REGION]=$total_instance_count
  region_asg_instances[$REGION]=$asg_instance_count

  printf "| %-14s | %-14s | %-14s |\n" "$REGION" "$total_instance_count" "$asg_instance_count"
done
echo "+----------------+----------------+----------------+"
echo ""

# Compare EC2 instances with ASG instances
for REGION in "${!region_total_instances[@]}"; do
  if [ "${region_total_instances[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    # Get instance lists
    ec2_instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text)

    asg_instances=$(aws autoscaling describe-auto-scaling-instances --region "$REGION" --profile "$PROFILE" \
      --query 'AutoScalingInstances[*].InstanceId' --output text)

    # Check each EC2 instance
    for INSTANCE_ID in $ec2_instances; do
      if echo "$asg_instances" | grep -q "$INSTANCE_ID"; then
        STATUS="${GREEN}Compliant (Managed by ASG)${NC}"
      else
        STATUS="${RED}Non-Compliant (Not in ASG)${NC}"
      fi

      # Print audit details
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo "Status: $STATUS"
      echo "--------------------------------------------------"
    done
  fi
done

echo "Audit completed for all regions."
