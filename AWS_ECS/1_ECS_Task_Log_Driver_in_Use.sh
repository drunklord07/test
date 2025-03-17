#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon ECS Task Definition Log Configuration"
criteria="Checks if ECS Task Definitions have a log driver configured for each container."

# Commands used
command_used="Commands Used:
  1. aws ecs list-task-definitions --region \$REGION --status ACTIVE --query 'taskDefinitionArns'
  2. aws ecs describe-task-definition --region \$REGION --task-definition <TASK_DEF_ARN> --query 'taskDefinition.containerDefinitions[*].{Container:name,LogDriver:logConfiguration.logDriver}'"

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
echo "Region         | Total Task Definitions | Non-Compliant Task Definitions"
echo "+--------------+----------------------+-------------------------------+"

declare -A total_tasks
declare -A non_compliant_tasks
non_compliant_found=false

# Step 1: Get ECS Task Definitions
for REGION in $regions; do
    task_def_arns=$(aws ecs list-task-definitions --region "$REGION" --profile "$PROFILE" --status ACTIVE --query 'taskDefinitionArns' --output text 2>/dev/null)
    task_count=$(echo "$task_def_arns" | wc -w)
    non_compliant_count=0

    # Step 2: Check Log Driver Configuration
    for TASK_DEF_ARN in $task_def_arns; do
        log_config=$(aws ecs describe-task-definition --region "$REGION" --profile "$PROFILE" --task-definition "$TASK_DEF_ARN" --query 'taskDefinition.containerDefinitions[*].{Container:name,LogDriver:logConfiguration.logDriver}' --output text 2>/dev/null)

        # Check if any container has "None" as LogDriver
        if echo "$log_config" | grep -q -E "\sNone\s"; then
            ((non_compliant_count++))
            non_compliant_found=true
            echo -e "${RED}Region: $REGION | Task Definition: $TASK_DEF_ARN | Missing Log Driver${NC}"
            echo "----------------------------------------------------------------"
        fi
    done

    total_tasks["$REGION"]=$task_count
    non_compliant_tasks["$REGION"]=$non_compliant_count
    printf "| %-14s | %-22s | %-30s |\n" "$REGION" "$task_count" "$non_compliant_count"
done

echo "+--------------+----------------------+-------------------------------+"
echo ""

# Final Compliance Check
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All ECS task definitions have log drivers configured. No issues found.${NC}"
fi

echo "Audit completed for all regions."
