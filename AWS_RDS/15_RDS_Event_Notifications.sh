#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS Event Subscriptions"
criteria="This script verifies whether Amazon RDS event subscriptions are configured in each AWS region."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-event-subscriptions --region \$REGION --query 'EventSubscriptionsList'"

# Display script metadata
echo ""
echo "---------------------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
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
echo "+----------------+--------------------------+"
echo "| Region         | Event Subscriptions      |"
echo "+----------------+--------------------------+"

# Collect subscription count per region
declare -A region_subscription_count
non_compliant_found=false

for REGION in $regions; do
  subscriptions=$(aws rds describe-event-subscriptions --region "$REGION" --profile "$PROFILE" \
    --query 'EventSubscriptionsList' --output json)

  subscription_count=$(echo "$subscriptions" | grep -o '{' | wc -l)
  region_subscription_count["$REGION"]=$subscription_count

  printf "| %-14s | %-24s |\n" "$REGION" "$subscription_count"

  if [[ "$subscription_count" -eq 0 ]]; then
    non_compliant_found=true
  fi
done

echo "+----------------+--------------------------+"
echo ""

# List regions with no event subscriptions
if [ "$non_compliant_found" = true ]; then
  echo "Regions with no RDS event subscriptions:"
  for REGION in "${!region_subscription_count[@]}"; do
    if [[ "${region_subscription_count[$REGION]}" -eq 0 ]]; then
      echo "- $REGION"
    fi
  done
else
  echo "All regions have RDS event subscriptions configured."
fi

echo "Audit completed for all regions."
