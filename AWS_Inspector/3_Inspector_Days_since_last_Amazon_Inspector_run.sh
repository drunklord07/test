#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Inspector assessment templates and completed assessment runs."
criteria="Lists all Inspector assessment templates and verifies if any completed assessment runs exist within a specified time range."

# Commands used
command_used="Commands Used:
  aws inspector list-assessment-templates --region \$REGION
  aws inspector list-assessment-runs --region \$REGION --assessment-template-arns <template_arn> --filter states=\"COMPLETED\",completionTimeRange={beginDate=\"<timestamp>\",endDate=\"<timestamp>\"}"

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

# Define the time range (Epoch timestamps)
BEGIN_DATE="1700000000"  # Example: Start time for assessment runs
END_DATE="1705000000"    # Example: End time for assessment runs

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Assessment Template ARN                          | Completed Assessment Runs"
echo "+--------------+--------------------------------------------------+---------------------------+"

declare -A completed_runs

# Step 1: Fetch Inspector Assessment Templates Per Region
for REGION in $regions; do
    template_arns=$(aws inspector list-assessment-templates --region "$REGION" --profile "$PROFILE" --query 'assessmentTemplateArns' --output text 2>/dev/null)

    if [[ -z "$template_arns" ]]; then
        continue
    fi

    for TEMPLATE_ARN in $template_arns; do
        assessment_run_arns=$(aws inspector list-assessment-runs --region "$REGION" --profile "$PROFILE" \
            --assessment-template-arns "$TEMPLATE_ARN" \
            --filter "states=COMPLETED,completionTimeRange={beginDate=\"$BEGIN_DATE\",endDate=\"$END_DATE\"}" \
            --query 'assessmentRunArns' --output text 2>/dev/null)
        
        if [[ -n "$assessment_run_arns" ]]; then
            completed_runs["$REGION|$TEMPLATE_ARN"]="$assessment_run_arns"
            printf "| %-14s | %-48s | %-25s |\n" "$REGION" "$TEMPLATE_ARN" "YES"
        else
            printf "| %-14s | %-48s | %-25s |\n" "$REGION" "$TEMPLATE_ARN" "NO"
        fi
    done
done

echo "+--------------+--------------------------------------------------+---------------------------+"
echo ""

# Step 2: Audit Summary
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Inspector Completed Assessment Runs)"
echo "---------------------------------------------------------------------"
if [[ ${#completed_runs[@]} -eq 0 ]]; then
    echo "No completed assessment runs found within the specified time range across all regions."
else
    for key in "${!completed_runs[@]}"; do
        IFS="|" read -r REGION TEMPLATE_ARN <<< "$key"
        echo "$REGION | Assessment Template: $TEMPLATE_ARN | Completed Runs: ${completed_runs[$key]}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
