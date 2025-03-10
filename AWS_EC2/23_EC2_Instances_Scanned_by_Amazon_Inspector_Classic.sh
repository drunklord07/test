#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Inspector Assessment Targets & Runs"
criteria="This script verifies Amazon Inspector assessment templates, targets, associated EC2 instances, and exclusions to ensure proper security evaluations."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws inspector list-assessment-templates
  3. aws inspector describe-assessment-templates
  4. aws inspector describe-assessment-targets
  5. aws inspector describe-resource-groups
  6. aws inspector preview-agents
  7. aws inspector list-exclusions
  8. aws inspector describe-exclusions"

# Color codes
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

# Table Header
echo "+----------------+---------------------------+"
echo "| Region         | Templates Found           |"
echo "+----------------+---------------------------+"

declare -A region_template_counts

for REGION in $regions; do
  TEMPLATE_ARNS=$(aws inspector list-assessment-templates --region "$REGION" --profile "$PROFILE" \
    --query 'assessmentTemplateArns[*]' --output text)

  template_count=$(echo "$TEMPLATE_ARNS" | wc -w)
  region_template_counts[$REGION]=$template_count

  printf "| %-14s | %-25s |\n" "$REGION" "$template_count"
done

echo "+----------------+---------------------------+"
echo ""

for REGION in "${!region_template_counts[@]}"; do
  echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

  TEMPLATE_ARNS=$(aws inspector list-assessment-templates --region "$REGION" --profile "$PROFILE" \
    --query 'assessmentTemplateArns[*]' --output text)

  if [[ -z "$TEMPLATE_ARNS" ]]; then
    echo "No assessment templates found in $REGION."
    continue
  fi

  for TEMPLATE_ARN in $TEMPLATE_ARNS; do
    echo "--------------------------------------------------"
    echo "Checking Template: $TEMPLATE_ARN"
    
    # Get associated assessment target
    TARGET_ARN=$(aws inspector describe-assessment-templates --region "$REGION" --profile "$PROFILE" \
      --assessment-template-arns "$TEMPLATE_ARN" \
      --query 'assessmentTemplates[*].assessmentTargetArn' --output text)

    echo "Assessment Target: $TARGET_ARN"

    # Check if the target uses a resource group
    RESOURCE_GROUP_ARN=$(aws inspector describe-assessment-targets --region "$REGION" --profile "$PROFILE" \
      --assessment-target-arns "$TARGET_ARN" \
      --query 'assessmentTargets[*].resourceGroupArn' --output text)

    if [[ -n "$RESOURCE_GROUP_ARN" && "$RESOURCE_GROUP_ARN" != "None" ]]; then
      echo "Target uses a limited resource group: $RESOURCE_GROUP_ARN"
      
      # Get the resource group's tags
      TAGS=$(aws inspector describe-resource-groups --region "$REGION" --profile "$PROFILE" \
        --resource-group-arns "$RESOURCE_GROUP_ARN" \
        --query 'resourceGroups[*].tags[]' --output json)
      echo "Resource Group Tags: $TAGS"
    else
      echo "Target includes all EC2 instances in the region."
    fi

    # Preview instances included in the target
    INSTANCE_PREVIEW=$(aws inspector preview-agents --region "$REGION" --profile "$PROFILE" \
      --preview-agents-arn "$TARGET_ARN" \
      --query 'agentPreviews[*].{ID:agentId,agentHealth:agentHealth}' --output json)
    echo "Instance Preview: $INSTANCE_PREVIEW"

    # Get last assessment run ARN
    LAST_RUN_ARN=$(aws inspector describe-assessment-templates --region "$REGION" --profile "$PROFILE" \
      --assessment-template-arns "$TEMPLATE_ARN" \
      --query 'assessmentTemplates[*].lastAssessmentRunArn' --output text)

    if [[ -z "$LAST_RUN_ARN" || "$LAST_RUN_ARN" == "None" ]]; then
      echo "No previous assessment runs found for this template."
      continue
    fi

    echo "Last Assessment Run: $LAST_RUN_ARN"

    # List exclusions from the last run
    EXCLUSION_ARNS=$(aws inspector list-exclusions --region "$REGION" --profile "$PROFILE" \
      --assessment-run-arn "$LAST_RUN_ARN" \
      --query 'exclusionArns[*]' --output text)

    if [[ -n "$EXCLUSION_ARNS" ]]; then
      echo "Instances excluded from assessment:"
      EXCLUSION_DETAILS=$(aws inspector describe-exclusions --region "$REGION" --profile "$PROFILE" \
        --exclusion-arns $EXCLUSION_ARNS --query 'exclusions' --output json)
      echo "$EXCLUSION_DETAILS"
    else
      echo "No exclusions found."
    fi

    echo "--------------------------------------------------"
  done
done

echo "Audit completed for all regions."
