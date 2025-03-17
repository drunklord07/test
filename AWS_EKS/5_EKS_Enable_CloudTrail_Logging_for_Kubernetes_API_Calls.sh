#!/bin/bash

# Description and Criteria
description="AWS Audit for CloudTrail Logging Status"
criteria="This script checks whether CloudTrail trails are enabled and logging events in each AWS region."

# Commands used
command_used="Commands Used:
  1. aws cloudtrail list-trails --region \$REGION --query 'Trails[*].Name' --output text
  2. aws cloudtrail get-trail-status --region \$REGION --name \$TRAIL --query 'IsLogging' --output text"

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
echo "Region         | Total Trails"
echo "+--------------+-------------+"

declare -A total_trails
declare -A non_compliant_trails

# Audit each region
for REGION in $regions; do
  # Get all CloudTrail trail names
  trails=$(aws cloudtrail list-trails --region "$REGION" --profile "$PROFILE" --query 'Trails[*].Name' --output text)

  trail_count=0
  non_compliant_list=()

  for TRAIL in $trails; do
    ((trail_count++))

    # Get trail logging status
    is_logging=$(aws cloudtrail get-trail-status --region "$REGION" --profile "$PROFILE" \
      --name "$TRAIL" --query 'IsLogging' --output text)

    if [[ "$is_logging" != "True" ]]; then
      non_compliant_list+=("$TRAIL (Logging Disabled)")
    fi
  done

  total_trails["$REGION"]=$trail_count
  non_compliant_trails["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-11s |\n" "$REGION" "$trail_count"
done

echo "+--------------+-------------+"
echo ""

# Audit Section
if [ ${#non_compliant_trails[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant CloudTrail Trails:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_trails[@]}"; do
    if [[ -n "${non_compliant_trails[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Trails:"
      for trail in ${non_compliant_trails[$region]}; do
        echo " - $trail"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All CloudTrail trails are enabled and logging events.${NC}"
fi

echo "Audit completed for all regions."
