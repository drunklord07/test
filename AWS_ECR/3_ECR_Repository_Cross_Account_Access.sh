#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon ECR Cross-Account Access Configuration"
criteria="Checks if Amazon ECR repositories have unauthorized cross-account access."

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

# Trusted AWS Account IDs (Replace with your organization's trusted account IDs)
trusted_accounts=("111122223333" "444455556666" "777788889999")

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header (Instant Display)
echo "Region         | Total Repositories | Non-Compliant Repositories"
echo "+--------------+-------------------+----------------------------+"

declare -A total_repos
declare -A non_compliant_repos
non_compliant_found=false

# Step 1: Get repository names
for REGION in $regions; do
    repo_names=$(aws ecr describe-repositories --region "$REGION" --profile "$PROFILE" --query 'repositories[*].repositoryName' --output text 2>/dev/null)
    repo_count=$(echo "$repo_names" | wc -w)
    non_compliant_count=0

    # Step 2: Check repository policies
    for REPO in $repo_names; do
        policy_json=$(aws ecr get-repository-policy --region "$REGION" --profile "$PROFILE" --repository-name "$REPO" --query 'policyText' --output json 2>/dev/null)

        if [[ -z "$policy_json" ]]; then
            continue
        fi

        # Extract Account IDs from Principal
        account_ids=$(echo "$policy_json" | grep -oP '(?<=arn:aws:iam::)[0-9]+(?=:root)' | sort -u)

        for account in $account_ids; do
            if [[ ! " ${trusted_accounts[*]} " =~ " ${account} " ]]; then
                ((non_compliant_count++))
                non_compliant_found=true
                echo -e "${RED}Region: $REGION | Repository: $REPO | Unauthorized Cross-Account Access: $account${NC}"
                echo "----------------------------------------------------------------"
            fi
        done
    done

    total_repos["$REGION"]=$repo_count
    non_compliant_repos["$REGION"]=$non_compliant_count
    printf "| %-14s | %-17s | %-26s |\n" "$REGION" "$repo_count" "$non_compliant_count"
done

echo "+--------------+-------------------+----------------------------+"
echo ""

# Final Compliance Check
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All repositories have secure cross-account access. No issues found.${NC}"
fi

echo "Audit completed for all regions."
