#!/bin/bash

# Description and Criteria
description="AWS Audit for Auto Scaling Group (ASG) Capacity Rebalancing"
criteria="This script checks if Capacity Rebalancing is enabled for each Auto Scaling Group (ASG).
If Capacity Rebalancing is disabled, the ASG is marked as 'Non-Compliant'."

# Command being used
command_used="Commands Used:
  1. aws autoscaling describe-regions --query 'Regions[*].RegionName' --output text
  2. aws autoscaling describe-auto-scaling-groups --region \$REGION --query 'AutoScalingGroups[*].AutoScalingGroupName'
  3. aws autoscaling describe-auto-scaling-groups --region \$REGION --auto-scaling-group-names \$ASG_NAME --query 'AutoScalingGroups[*].CapacityRebalance'"

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
echo "\n+----------------+----------------+"
echo "| Region         | ASGs Found      |"
echo "+----------------+----------------+"

# Audit each region
declare -A region_asg_count
for REGION in $regions; do
  asgs=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --profile "$PROFILE" \
    --query 'AutoScalingGroups[*].AutoScalingGroupName' --output text)

  asg_count=$(echo "$asgs" | wc -w)
  region_asg_count[$REGION]=$asg_count

  printf "| %-14s | %-14s |\n" "$REGION" "$asg_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each Auto Scaling Group to check Capacity Rebalancing status
for REGION in "${!region_asg_count[@]}"; do
  if [ "${region_asg_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for ASG_NAME in $(aws autoscaling describe-auto-scaling-groups --region "$REGION" --profile "$PROFILE" \
      --query 'AutoScalingGroups[*].AutoScalingGroupName' --output text); do

      # Get Capacity Rebalance status
      CAPACITY_REBALANCE=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --profile "$PROFILE" \
        --auto-scaling-group-names "$ASG_NAME" --query 'AutoScalingGroups[*].CapacityRebalance' --output text)

      # Check if Capacity Rebalancing is enabled
      if [ "$CAPACITY_REBALANCE" == "False" ]; then
        STATUS="${RED}Non-Compliant (Capacity Rebalancing Disabled)${NC}"
      else
        STATUS="${GREEN}Compliant (Capacity Rebalancing Enabled)${NC}"
      fi

      # Print audit details
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Auto Scaling Group: $ASG_NAME"
      echo "Capacity Rebalancing: $CAPACITY_REBALANCE"
      echo "Status: $STATUS"
      echo "--------------------------------------------------"
    done
  fi
done

echo "Audit completed for all regions."
