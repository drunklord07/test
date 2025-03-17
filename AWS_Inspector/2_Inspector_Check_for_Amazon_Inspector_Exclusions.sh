#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Inspector assessment runs and exclusions."
criteria="Identifies exclusions in Amazon Inspector assessment runs, including scope, description, and recommendations."

# Commands used
command_used="Commands Used:
  aws inspector list-assessment-runs --region \$REGION
  aws inspector list-exclusions --region \$REGION --assessment-run-arn <assessment_run_arn>
  aws inspector describe-exclusions --region \$REGION --exclusion-arns <exclusion_arn>"

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
echo "Region         | Assessment Run ARN                                  | Exclusion ARN                                      | Title"
echo "+--------------+--------------------------------------------------+--------------------------------------------------+--------------------------------------+"

declare -A non_compliant_exclusions

# Step 1: Fetch Inspector Assessment Runs Per Region
for REGION in $regions; do
    assessment_run_arns=$(aws inspector list-assessment-runs --region "$REGION" --profile "$PROFILE" --query 'assessmentRunArns' --output text 2>/dev/null)

    if [[ -z "$assessment_run_arns" ]]; then
        continue
    fi

    for ASSESSMENT_RUN_ARN in $assessment_run_arns; do
        exclusion_arns=$(aws inspector list-exclusions --region "$REGION" --profile "$PROFILE" --assessment-run-arn "$ASSESSMENT_RUN_ARN" --query 'exclusionArns' --output text 2>/dev/null)
        
        if [[ -z "$exclusion_arns" ]]; then
            continue
        fi

        for EXCLUSION_ARN in $exclusion_arns; do
            exclusion_details=$(aws inspector describe-exclusions --region "$REGION" --profile "$PROFILE" --exclusion-arns "$EXCLUSION_ARN" --query 'exclusions[*].[title, scopes[0].value, description, recommendation]' --output text 2>/dev/null)
            
            if [[ -z "$exclusion_details" ]]; then
                continue
            fi

            IFS=$'\t' read -r TITLE INSTANCE_ID DESCRIPTION RECOMMENDATION <<< "$exclusion_details"

            non_compliant_exclusions["$REGION|$ASSESSMENT_RUN_ARN|$EXCLUSION_ARN"]="Title: $TITLE | Instance: $INSTANCE_ID"

            printf "| %-14s | %-48s | %-48s | %-36s |\n" "$REGION" "$ASSESSMENT_RUN_ARN" "$EXCLUSION_ARN" "$TITLE"
        done
    done
done

echo "+--------------+--------------------------------------------------+--------------------------------------------------+--------------------------------------+"
echo ""

# Step 2: Audit for Non-Compliant Exclusions
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Inspector Exclusions)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_exclusions[@]} -eq 0 ]]; then
    echo "No exclusions found in Amazon Inspector assessment runs across all regions."
else
    for key in "${!non_compliant_exclusions[@]}"; do
        IFS="|" read -r REGION ASSESSMENT_RUN_ARN EXCLUSION_ARN <<< "$key"
        echo "$REGION | Assessment Run: $ASSESSMENT_RUN_ARN | Exclusion ARN: $EXCLUSION_ARN | ${non_compliant_exclusions[$key]}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
