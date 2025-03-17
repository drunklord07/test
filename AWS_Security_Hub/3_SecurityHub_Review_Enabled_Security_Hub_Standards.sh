#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Hub Enabled Standards Compliance"
criteria="Identifies all Security Hub standards enabled across AWS regions."

# Commands used
command_used="Commands Used:
  1. aws securityhub get-enabled-standards --region \$REGION --query 'StandardsSubscriptions[*].StandardsArn'"

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

# Table Header (Instant Display)
echo "Region         | Enabled Standards"
echo "+--------------+--------------------+"

declare -A total_standards

# Step 1: Quickly gather total enabled standards per region and display the table
for REGION in $regions; do
    standards_count=$(aws securityhub get-enabled-standards --region "$REGION" --profile "$PROFILE" --query 'length(StandardsSubscriptions)' --output text 2>/dev/null)
    
    # If no standards are enabled, set count to 0
    if [[ "$standards_count" == "None" ]]; then
        standards_count=0
    fi

    total_standards["$REGION"]=$standards_count
    printf "| %-14s | %-18s |\n" "$REGION" "$standards_count"
done

echo "+--------------+--------------------+"
echo ""

# Step 2: List and Evaluate Enabled Security Hub Standards
echo -e "${PURPLE}Checking Security Hub Enabled Standards...${NC}"
non_compliant_found=false

for REGION in "${!total_standards[@]}"; do
    if [[ "${total_standards[$REGION]}" -eq 0 ]]; then
        continue
    fi

    echo -e "${PURPLE}Region: $REGION${NC}"
    
    # Fetch details of enabled standards
    enabled_standards=$(aws securityhub get-enabled-standards --region "$REGION" --profile "$PROFILE" --query 'StandardsSubscriptions[*].[StandardsArn, StandardsSubscriptionArn]' --output text 2>/dev/null)
    
    while read -r standards_arn standards_subscription_arn; do
        echo -e "${GREEN}Enabled Standard:${NC} $standards_arn"
        echo -e "${GREEN}Subscription ARN:${NC} $standards_subscription_arn"
        echo "------------------------------------------------------------"
    done <<< "$enabled_standards"
done

# Step 3: Final Compliance Message
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All enabled Security Hub standards have been reviewed.${NC}"
fi

echo "Audit completed for all regions."
