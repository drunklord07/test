#!/bin/bash

# Description and Criteria
description="AWS Security Hub Findings Compliance Audit"
criteria="Retrieves Security Hub findings and categorizes them by severity."

# Commands used
command_used="Commands Used:
  1. aws securityhub get-findings --region \$REGION --query 'Findings[*].[Id,Severity.Label,Title,AwsAccountId]' --output text"

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
echo "Region         | Total Findings"
echo "+--------------+----------------+"

declare -A total_findings

# Step 1: Retrieve total findings per region and display the table
for REGION in $regions; do
    findings_count=$(aws securityhub get-findings --region "$REGION" --profile "$PROFILE" --query 'length(Findings)' --output text 2>/dev/null)
    total_findings["$REGION"]=$findings_count
    printf "| %-14s | %-14s |\n" "$REGION" "$findings_count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Findings Compliance Audit
echo -e "${PURPLE}Checking Security Hub Findings Compliance...${NC}"
non_compliant_found=false

for REGION in "${!total_findings[@]}"; do
    findings=$(aws securityhub get-findings --region "$REGION" --profile "$PROFILE" --query 'Findings[*].[Id,Severity.Label,Title,AwsAccountId]' --output text 2>/dev/null)

    if [[ -z "$findings" ]]; then
        continue
    fi

    while IFS=$'\t' read -r finding_id severity title aws_account_id; do
        if [[ -z "$finding_id" ]]; then
            continue
        fi

        if [[ "$severity" == "HIGH" || "$severity" == "MEDIUM" || "$severity" == "LOW" ]]; then
            non_compliant_found=true
            color=$RED
        else
            color=$GREEN
        fi

        echo -e "${color}Region: $REGION${NC}"
        echo -e "${color}Finding ID: $finding_id${NC}"
        echo -e "${color}Title: $title${NC}"
        echo -e "${color}Severity: ${severity:-UNKNOWN}${NC}"
        echo -e "${color}AWS Account: $aws_account_id${NC}"
        echo "----------------------------------------------------------------"
    done <<< "$findings"
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}No findings found. All compliant!${NC}"
fi

echo "Audit completed for all regions."
