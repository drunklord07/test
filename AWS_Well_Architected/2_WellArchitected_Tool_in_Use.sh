#!/bin/bash

# Description and Criteria
description="AWS Audit for Well-Architected Workload Presence"
criteria="Identifies if any Well-Architected workloads exist in the selected AWS region."

# Commands used
command_used="Commands Used:
  1. aws wellarchitected list-workloads --region \$REGION --query 'WorkloadSummaries[*].WorkloadId'"

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
non_compliant_found=false

# Step 1: Gather total workloads per region and display the table
for REGION in $regions; do
    workload_count=$(aws wellarchitected list-workloads --region "$REGION" --profile "$PROFILE" --query 'WorkloadSummaries[*].WorkloadId' --output text 2>/dev/null | wc -w)
    total_workloads["$REGION"]=$workload_count
    printf "| %-14s | %-14s |\n" "$REGION" "$workload_count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Workload Presence Audit
echo -e "${PURPLE}Checking Well-Architected Workload Presence...${NC}"

for REGION in "${!total_workloads[@]}"; do
    if [[ "${total_workloads[$REGION]}" -eq 0 ]]; then
        non_compliant_found=true
        echo -e "${RED}Region: $REGION${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (No Well-Architected Workloads Found)${NC}"
        echo "----------------------------------------------------------------"
    fi
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All regions have Well-Architected workloads.${NC}"
fi

echo "Audit completed for all regions."
