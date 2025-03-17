#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon ECR Image Scanning Configuration"
criteria="Checks if Amazon ECR image scanning is enabled at both the repository and registry levels."

# Commands used
command_used="Commands Used:
  1. aws ecr describe-repositories --region \$REGION --query 'repositories[*].repositoryName'
  2. aws ecr describe-repositories --region \$REGION --repository-names <REPO_NAME> --query 'repositories[*].imageScanningConfiguration.scanOnPush'
  3. aws ecr get-registry-scanning-configuration --region \$REGION --query 'scanningConfiguration.scanType'"

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
echo "Region         | Total Repositories | Non-Compliant Repositories"
echo "+--------------+-------------------+----------------------------+"

declare -A total_repos
declare -A non_compliant_repos
non_compliant_found=false

# Step 1: Check repository-level scanning
for REGION in $regions; do
    repo_names=$(aws ecr describe-repositories --region "$REGION" --profile "$PROFILE" --query 'repositories[*].repositoryName' --output text 2>/dev/null)
    repo_count=$(echo "$repo_names" | wc -w)
    non_compliant_count=0

    # Step 2: Check each repository for Scan on Push feature
    for REPO in $repo_names; do
        scan_status=$(aws ecr describe-repositories --region "$REGION" --profile "$PROFILE" --repository-names "$REPO" --query 'repositories[*].imageScanningConfiguration.scanOnPush' --output text 2>/dev/null)

        if [[ "$scan_status" == "False" ]]; then
            ((non_compliant_count++))
            non_compliant_found=true
            echo -e "${RED}Region: $REGION | Repository: $REPO | Scan on Push: DISABLED${NC}"
            echo "----------------------------------------------------------------"
        fi
    done

    # Step 3: Check registry-level scanning
    registry_scan=$(aws ecr get-registry-scanning-configuration --region "$REGION" --profile "$PROFILE" --query 'scanningConfiguration.scanType' --output text 2>/dev/null)
    if [[ "$registry_scan" == "BASIC" ]]; then
        registry_compliance_status="BASIC (Not Enhanced)"
    else
        registry_compliance_status="ENHANCED (Compliant)"
    fi

    total_repos["$REGION"]=$repo_count
    non_compliant_repos["$REGION"]=$non_compliant_count
    printf "| %-14s | %-17s | %-26s |\n" "$REGION" "$repo_count" "$non_compliant_count"
done

echo "+--------------+-------------------+----------------------------+"
echo ""

# Final Compliance Check
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All repositories have Scan on Push enabled. No issues found.${NC}"
fi

echo "Audit completed for all regions."
