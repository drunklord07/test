#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Inspector findings to identify security vulnerabilities."
criteria="Identifies security findings reported by Amazon Inspector, including severity, description, and recommendations."

# Commands used
command_used="Commands Used:
  aws inspector list-findings --region \$REGION
  aws inspector describe-findings --region \$REGION --finding-arns <finding_arn>"

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
echo "Region         | Finding ARN                                       | Severity  | Title"
echo "+--------------+--------------------------------------------------+-----------+--------------------------------------+"

declare -A non_compliant_findings

# Step 1: Fetch Inspector Findings Per Region
for REGION in $regions; do
    finding_arns=$(aws inspector list-findings --region "$REGION" --profile "$PROFILE" --query 'findingArns' --output text 2>/dev/null)

    if [[ -z "$finding_arns" ]]; then
        continue
    fi

    for FINDING_ARN in $finding_arns; do
        finding_details=$(aws inspector describe-findings --region "$REGION" --profile "$PROFILE" --finding-arns "$FINDING_ARN" --query 'findings[0].[title, severity, description, recommendation]' --output text 2>/dev/null)
        
        if [[ -z "$finding_details" ]]; then
            continue
        fi

        IFS=$'\t' read -r TITLE SEVERITY DESCRIPTION RECOMMENDATION <<< "$finding_details"

        if [[ "$TITLE" != "No potential security issues found" ]]; then
            non_compliant_findings["$REGION|$FINDING_ARN"]="Severity: $SEVERITY | $TITLE"
        fi

        printf "| %-14s | %-48s | %-9s | %-36s |\n" "$REGION" "$FINDING_ARN" "$SEVERITY" "$TITLE"
    done
done

echo "+--------------+--------------------------------------------------+-----------+--------------------------------------+"
echo ""

# Step 2: Audit for Non-Compliant Findings
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Inspector Findings with Security Issues)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_findings[@]} -eq 0 ]]; then
    echo "No security issues found by Amazon Inspector in any region."
else
    for key in "${!non_compliant_findings[@]}"; do
        IFS="|" read -r REGION FINDING_ARN <<< "$key"
        echo "$REGION | Finding ARN: $FINDING_ARN | ${non_compliant_findings[$key]}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
