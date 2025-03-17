#!/bin/bash

# Description and Criteria
description="AWS Audit for Neptune database instances to check Auto Minor Version Upgrade status."
criteria="Identifies Neptune database instances where Auto Minor Version Upgrade is disabled, which may lead to outdated engine versions."

# Commands used
command_used="Commands Used:
  aws neptune describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceIdentifier'
  aws neptune describe-db-instances --region \$REGION --db-instance-identifier <instance_id> --query 'DBInstances[*].AutoMinorVersionUpgrade'"

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
echo "Region         | Total Neptune Instances | Non-Compliant Instances"
echo "+--------------+------------------------+-------------------------+"

declare -A non_compliant_instances

# Step 1: Fetch Neptune Instances Per Region
for REGION in $regions; do
    instance_ids=$(aws neptune describe-db-instances --region "$REGION" --profile "$PROFILE" --query 'DBInstances[*].DBInstanceIdentifier' --output text 2>/dev/null)

    if [[ -z "$instance_ids" ]]; then
        continue
    fi

    total_instances=0
    non_compliant_count=0
    non_compliant_details=""

    for INSTANCE_ID in $instance_ids; do
        ((total_instances++))
        auto_upgrade_status=$(aws neptune describe-db-instances --region "$REGION" --profile "$PROFILE" --db-instance-identifier "$INSTANCE_ID" --query 'DBInstances[*].AutoMinorVersionUpgrade' --output text 2>/dev/null)

        [[ "$auto_upgrade_status" == "None" ]] && auto_upgrade_status="false"

        if [[ "$auto_upgrade_status" == "False" ]]; then
            ((non_compliant_count++))
            non_compliant_details+="Region: $REGION | Instance ID: $INSTANCE_ID | Auto Minor Version Upgrade: $auto_upgrade_status"$'\n'
        fi
    done

    if [[ $non_compliant_count -gt 0 ]]; then
        non_compliant_instances["$REGION"]="$non_compliant_details"
    fi

    printf "| %-14s | %-22s | %-23s |\n" "$REGION" "$total_instances" "$non_compliant_count"
done

echo "+--------------+------------------------+-------------------------+"
echo ""

# Step 2: Audit for Non-Compliant Instances
echo "---------------------------------------------------------------------"
echo "Audit Results (Neptune instances where Auto Minor Version Upgrade is disabled)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_instances[@]} -eq 0 ]]; then
    echo "All Neptune database instances have Auto Minor Version Upgrade enabled."
else
    for REGION in "${!non_compliant_instances[@]}"; do
        echo "Region: $REGION"
        echo "${non_compliant_instances[$REGION]}"
        echo "---------------------------------------------------------------------"
    done
fi

echo "Audit completed for all regions."
