#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Inspector v2 Findings"
criteria="Lists Inspector v2 findings, fetches detailed information, and verifies severity levels for security analysis."

# Commands used
command_used="Commands Used:
  aws inspector2 list-findings --region \$REGION --query 'findings[].findingArn'
  aws inspector2 list-findings --region \$REGION --filter-criteria '{\"findingArn\": [{\"comparison\": \"EQUALS\", \"value\": \"<finding-arn>\"}]}' --query 'findings[]'"

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
echo "Region         | Finding ARN                                        | Severity   | Status    "
echo "+--------------+--------------------------------------------------+------------+-----------+"

declare -A findings_details

# Step 1: Fetch Amazon Inspector Findings Per Region
for REGION in $regions; do
    finding_arns=$(aws inspector2 list-findings --region "$REGION" --profile "$PROFILE" --query 'findings[].findingArn' --output text 2>/dev/null)

    if [[ -z "$finding_arns" ]]; then
        continue
    fi

    for FINDING_ARN in $finding_arns; do
        finding_details=$(aws inspector2 list-findings --region "$REGION" --profile "$PROFILE" \
            --filter-criteria "{\"findingArn\": [{\"comparison\": \"EQUALS\", \"value\": \"$FINDING_ARN\"}]}" \
            --query 'findings[0]' --output json 2>/dev/null)

        if [[ -n "$finding_details" ]]; then
            severity=$(echo "$finding_details" | jq -r '.severity')
            status=$(echo "$finding_details" | jq -r '.status')

            findings_details["$REGION|$FINDING_ARN"]="$severity|$status"

            printf "| %-14s | %-48s | %-10s | %-9s |\n" "$REGION" "$FINDING_ARN" "$severity" "$status"
        fi
    done
done

echo "+--------------+--------------------------------------------------+------------+-----------+"
echo ""

# Step 2: Audit Summary
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Inspector v2 Findings)"
echo "---------------------------------------------------------------------"
if [[ ${#findings_details[@]} -eq 0 ]]; then
    echo "No findings detected across all regions."
else
    for key in "${!findings_details[@]}"; do
        IFS="|" read -r REGION FINDING_ARN <<< "$key"
        IFS="|" read -r SEVERITY STATUS <<< "${findings_details[$key]}"
        echo "$REGION | Finding: $FINDING_ARN | Severity: $SEVERITY | Status: $STATUS"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
