#!/bin/bash

# Description and Criteria
description="AWS Audit for AWS Backup Plans Lifecycle Configuration Compliance"
criteria="This script checks if AWS Backup plans have a lifecycle configuration enabled (MoveToColdStorageAfterDays and DeleteAfterDays)."

# Commands used
command_used="Commands Used:
  1. aws backup list-backup-plans --region \$REGION --query 'BackupPlansList[*].BackupPlanId' --output text
  2. aws backup get-backup-plan --region \$REGION --backup-plan-id \$PLAN_ID --query 'BackupPlan.Rules[*].{MoveToColdStorageAfterDays: Lifecycle.MoveToColdStorageAfterDays, DeleteAfterDays: Lifecycle.DeleteAfterDays}' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
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
echo "Region         | Total Backup Plans"
echo "+--------------+-------------------+"

declare -A total_plans
declare -A non_compliant_plans

# Audit each region
for REGION in $regions; do
  backup_plans=$(aws backup list-backup-plans --region "$REGION" --profile "$PROFILE" --query 'BackupPlansList[*].BackupPlanId' --output text 2>/dev/null)

  plan_count=0
  non_compliant_list=()

  for PLAN_ID in $backup_plans; do
    ((plan_count++))

    lifecycle_config=$(aws backup get-backup-plan --region "$REGION" --profile "$PROFILE" --backup-plan-id "$PLAN_ID" --query 'BackupPlan.Rules[*].{MoveToColdStorageAfterDays: Lifecycle.MoveToColdStorageAfterDays, DeleteAfterDays: Lifecycle.DeleteAfterDays}' --output text 2>/dev/null)

    if [[ -z "$lifecycle_config" ]]; then
      lifecycle_config="None None"
    fi

    move_to_cold=$(echo "$lifecycle_config" | awk '{print $1}')
    delete_after=$(echo "$lifecycle_config" | awk '{print $2}')
    
    if [[ "$move_to_cold" == "None" && "$delete_after" == "None" ]]; then
      non_compliant_list+=("$PLAN_ID (No Lifecycle Config)")
    fi
  done

  total_plans["$REGION"]=$plan_count
  non_compliant_plans["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-19s |\n" "$REGION" "$plan_count"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_plans[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant AWS Backup Plans:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_plans[@]}"; do
    if [[ -n "${non_compliant_plans[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Backup Plans:"
      for plan in ${non_compliant_plans[$region]}; do
        echo " - $plan"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS Backup plans have a valid lifecycle configuration.${NC}"
fi

echo "Audit completed for all regions."
