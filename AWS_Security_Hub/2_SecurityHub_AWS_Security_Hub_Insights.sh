#!/bin/bash

# Description and Criteria
description="AWS Security Hub Insights Compliance Audit"
criteria="Retrieves Security Hub insights and evaluates associated security findings."

# Commands used
command_used="Commands Used:
  1. aws securityhub get-insights --region \$REGION --query 'Insights[*].InsightArn'
  2. aws securityhub get-insight-results --region \$REGION --insight-arn INSIGHT_ARN
  3. aws securityhub get-findings --region \$REGION --filters file://insight-resource-id.json --query 'Findings[*].Id'"

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
echo "Region         | Total Insights"
echo "+--------------+----------------+"

declare -A total_insights

# Step 1: Retrieve total insights per region and display the table
for REGION in $regions; do
    insights_count=$(aws securityhub get-insights --region "$REGION" --profile "$PROFILE" --query 'length(Insights)' --output text 2>/dev/null)
    total_insights["$REGION"]=$insights_count
    printf "| %-14s | %-14s |\n" "$REGION" "$insights_count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Insights Compliance Audit
echo -e "${PURPLE}Checking Security Hub Insights Compliance...${NC}"
non_compliant_found=false

for REGION in "${!total_insights[@]}"; do
    insight_arns=$(aws securityhub get-insights --region "$REGION" --profile "$PROFILE" --query 'Insights[*].InsightArn' --output text 2>/dev/null)

    if [[ -z "$insight_arns" ]]; then
        continue
    fi

    for insight_arn in $insight_arns; do
        insight_results=$(aws securityhub get-insight-results --region "$REGION" --profile "$PROFILE" --insight-arn "$insight_arn" --query 'InsightResults.ResultValues[*].[Count,GroupByAttributeValue]' --output text 2>/dev/null)

        while IFS=$'\t' read -r count resource_arn; do
            if [[ -z "$count" || -z "$resource_arn" ]]; then
                continue
            fi

            # Create JSON filter file
            filter_file="insight-resource-id.json"
            echo "{ \"ResourceId\": [ { \"Value\": \"$resource_arn\", \"Comparison\": \"EQUALS\" } ] }" > "$filter_file"

            # Get Findings for the resource
            findings=$(aws securityhub get-findings --region "$REGION" --profile "$PROFILE" --filters file://"$filter_file" --query 'Findings[*].Id' --output text 2>/dev/null)

            if [[ -n "$findings" ]]; then
                non_compliant_found=true
                echo -e "${RED}Region: $REGION${NC}"
                echo -e "${RED}Insight ARN: $insight_arn${NC}"
                echo -e "${RED}Resource ARN: $resource_arn${NC}"
                echo -e "${RED}Total Findings: $count (NON-COMPLIANT)${NC}"
                echo "----------------------------------------------------------------"
            fi

            # Remove temporary file
            rm -f "$filter_file"
        done <<< "$insight_results"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}No findings found. All compliant!${NC}"
fi

echo "Audit completed for all regions."
