#!/bin/bash

# Description and Criteria
description="AWS Audit for Well-Architected Workload Risk Compliance"
criteria="Checks AWS Well-Architected workloads for HIGH-risk issues."

# Commands used
command_used="Commands Used:
  1. aws wellarchitected list-workloads --region \$REGION --query 'WorkloadSummaries[*].{WorkloadId:WorkloadId,WorkloadName:WorkloadName,RiskCounts:RiskCounts}'"

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
echo "Region         | Total Workloads"
echo "+--------------+----------------+"

declare -A total_workloads

# Step 1: Quickly gather total workloads per region and display the table
for REGION in $regions; do
    workloads_count=$(aws wellarchitected list-workloads --region "$REGION" --profile "$PROFILE" --query 'WorkloadSummaries[*].WorkloadId' --output text 2>/dev/null | wc -w)
    total_workloads["$REGION"]=$workloads_count
    printf "| %-14s | %-14s |\n" "$REGION" "$workloads_count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Workload Risk Compliance Audit
echo -e "${PURPLE}Checking Well-Architected Workload Risk Compliance...${NC}"
non_compliant_found=false

for REGION in "${!total_workloads[@]}"; do
    workload_data=$(aws wellarchitected list-workloads --region "$REGION" --profile "$PROFILE" --query 'WorkloadSummaries[*].[WorkloadId, WorkloadName, RiskCounts.HIGH]' --output text 2>/dev/null)

    if [[ -z "$workload_data" ]]; then
        continue
    fi

    while IFS=$'\t' read -r workload_id workload_name high_risk_count; do
        high_risk_count=${high_risk_count:-0}

        if [[ "$high_risk_count" -gt 0 ]]; then
            non_compliant_found=true
            echo -e "${RED}Region: $REGION${NC}"
            echo -e "${RED}Workload ID: $workload_id${NC}"
            echo -e "${RED}Workload Name: $workload_name${NC}"
            echo -e "${RED}High Risk Issues: $high_risk_count${NC}"
            echo "----------------------------------------------------------------"
        fi
    done <<< "$workload_data"
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All workloads have no HIGH-risk issues.${NC}"
fi

echo "Audit completed for all regions."
