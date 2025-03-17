#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon ECR Repository Public Access"
criteria="Identifies if any Amazon ECR repositories have a public access policy that allows unrestricted access."

# Commands used
command_used="Commands Used:
  1. aws ecr describe-repositories --region \$REGION --query 'repositories[*].repositoryName'
  2. aws ecr get-repository-policy --region \$REGION --repository-name <REPO_NAME> --query 'policyText'"

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
echo "Region         | Total Repositories | Public Repositories"
echo "+--------------+-------------------+---------------------+"

declare -A total_repos
declare -A public_repos
non_compliant_found=false

# Step 1: Gather repository counts and display the table
for REGION in $regions; do
    repo_names=$(aws ecr describe-repositories --region "$REGION" --profile "$PROFILE" --query 'repositories[*].repositoryName' --output text 2>/dev/null)
    repo_count=$(echo "$repo_names" | wc -w)
    public_count=0

    # Check repository policies for public access
    for REPO in $repo_names; do
        policy_json=$(aws ecr get-repository-policy --region "$REGION" --profile "$PROFILE" --repository-name "$REPO" --query 'policyText' --output text 2>/dev/null)
        
        if [[ "$policy_json" == *'"Effect": "Allow"'* && "$policy_json" == *'"Principal": "*"'* ]]; then
            ((public_count++))
            non_compliant_found=true
            echo -e "${RED}Region: $REGION | Repository: $REPO${NC}"
            echo -e "${RED}Status: NON-COMPLIANT (Public Access Enabled)${NC}"
            echo "----------------------------------------------------------------"
        fi
    done

    total_repos["$REGION"]=$repo_count
    public_repos["$REGION"]=$public_count
    printf "| %-14s | %-17s | %-19s |\n" "$REGION" "$repo_count" "$public_count"
done

echo "+--------------+-------------------+---------------------+"
echo ""

# Final Compliance Check
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All repositories are private. No public ECR repositories found.${NC}"
fi

echo "Audit completed for all regions."
