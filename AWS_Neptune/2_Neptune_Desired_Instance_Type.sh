#!/bin/bash

# Description and Criteria
description="AWS Audit for Neptune database instances to check if all instances use the same instance type."
criteria="Identifies Neptune database instances that are not using the required instance type, ensuring uniformity."

# Commands used
command_used="Commands Used:
  aws neptune describe-db-instances --region \$REGION --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass]'"

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

# Define the required instance type
REQUIRED_INSTANCE_TYPE="db.r4.xlarge"

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Total Neptune Instances | Non-Compliant Instances"
echo "+--------------+------------------------+-------------------------+"

declare -A non_compliant_instances

# Step 1: Fetch Neptune Instances Per Region
for REGION in $regions; do
    instance_data=$(aws neptune describe-db-instances --region "$REGION" --profile "$PROFILE" --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceClass]' --output text 2>/dev/null)

    if [[ -z "$instance_data" ]]; then
        continue
    fi

    total_instances=0
    non_compliant_count=0
    non_compliant_details=""

    while read -r INSTANCE_ID INSTANCE_TYPE; do
        ((total_instances++))
        if [[ "$INSTANCE_TYPE" != "$REQUIRED_INSTANCE_TYPE" ]]; then
            ((non_compliant_count++))
            non_compliant_details+="Region: $REGION | Instance ID: $INSTANCE_ID | Type: $INSTANCE_TYPE"$'\n'
        fi
    done <<< "$instance_data"

    if [[ $non_compliant_count -gt 0 ]]; then
        non_compliant_instances["$REGION"]="$non_compliant_details"
    fi

    printf "| %-14s | %-22s | %-23s |\n" "$REGION" "$total_instances" "$non_compliant_count"
done

echo "+--------------+------------------------+-------------------------+"
echo ""

# Step 2: Audit for Non-Compliant Instances
echo "---------------------------------------------------------------------"
echo "Audit Results (Neptune instances not using the required instance type)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_instances[@]} -eq 0 ]]; then
    echo "All Neptune database instances use the required instance type ($REQUIRED_INSTANCE_TYPE)."
else
    for REGION in "${!non_compliant_instances[@]}"; do
        echo "Region: $REGION"
        echo "${non_compliant_instances[$REGION]}"
        echo "---------------------------------------------------------------------"
    done
fi

echo "Audit completed for all regions."
