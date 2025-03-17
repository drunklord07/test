#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Hub Subscription Compliance"
criteria="Checks whether Security Hub is enabled in all AWS regions and retrieves the subscription date."

# Commands used
command_used="Commands Used:
  1. aws securityhub describe-hub --region \$REGION --query 'SubscribedAt'"

# Color codes
RED='\033[0;31m'
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

# Table Header
echo "Region         | Security Hub Subscription Date"
echo "+--------------+--------------------------------+"

declare -A security_hub_status

# Step 1: Check Security Hub status in each region
for REGION in $regions; do
    subscription_date=$(aws securityhub describe-hub --region "$REGION" --profile "$PROFILE" --query 'SubscribedAt' --output text 2>&1)

    if [[ "$subscription_date" == *"InvalidAccessException"* ]]; then
        security_hub_status["$REGION"]="Non-Compliant"
        printf "| %-14s | ${RED}%-30s${NC} |\n" "$REGION" "Not Enabled"
    else
        security_hub_status["$REGION"]="Compliant"
        printf "| %-14s | ${GREEN}%-30s${NC} |\n" "$REGION" "$subscription_date"
    fi
done

echo "+--------------+--------------------------------+"
echo ""

# Step 2: Summary of Compliant vs Non-Compliant Regions
compliant_count=0
non_compliant_count=0

for region in "${!security_hub_status[@]}"; do
    if [[ "${security_hub_status[$region]}" == "Compliant" ]]; then
        ((compliant_count++))
    else
        ((non_compliant_count++))
    fi
done

echo "Summary:"
echo -e "${GREEN}Compliant Regions: $compliant_count${NC}"
echo -e "${RED}Non-Compliant Regions: $non_compliant_count${NC}"
echo ""

echo "Audit completed for all regions."
-