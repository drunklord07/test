#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Inspector v2 Account Status"
criteria="Checks if Amazon Inspector v2 is enabled for multiple accounts across AWS regions."

# Commands used
command_used="Commands Used:
  aws inspector2 batch-get-account-status --region \$REGION --query 'accounts[*].[accountId,state.status]'"

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
echo "Region         | Account ID        | Inspector v2 Status"
echo "+--------------+------------------+--------------------+"

declare -A account_statuses

# Step 1: Fetch Amazon Inspector Account Status Per Region
for REGION in $regions; do
    account_data=$(aws inspector2 batch-get-account-status --region "$REGION" --profile "$PROFILE" --query 'accounts[*].[accountId,state.status]' --output json 2>/dev/null)

    if [[ -z "$account_data" || "$account_data" == "[]" ]]; then
        continue
    fi

    # Parse JSON output
    accounts=$(echo "$account_data" | jq -c '.[]')

    for account in $accounts; do
        account_id=$(echo "$account" | jq -r '.[0]')
        status=$(echo "$account" | jq -r '.[1]')

        account_statuses["$REGION|$account_id"]="$status"

        printf "| %-14s | %-16s | %-18s |\n" "$REGION" "$account_id" "$status"
    done
done

echo "+--------------+------------------+--------------------+"
echo ""

# Step 2: Audit Summary
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Inspector v2 Account Status)"
echo "---------------------------------------------------------------------"
if [[ ${#account_statuses[@]} -eq 0 ]]; then
    echo "No accounts found or Inspector v2 is disabled across all regions."
else
    for key in "${!account_statuses[@]}"; do
        IFS="|" read -r REGION ACCOUNT_ID <<< "$key"
        STATUS="${account_statuses[$key]}"
        echo "$REGION | Account: $ACCOUNT_ID | Status: $STATUS"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
