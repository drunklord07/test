#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS Database Instance Type Consistency"
criteria="This script checks all Amazon RDS database instances in each AWS region to verify if they all use the same instance type. If multiple instance types are found in a region, the environment is considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceClass'"

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
echo "+----------------+------------------+"
echo "| Region         | RDS Instances    |"
echo "+----------------+------------------+"

# Collect instance count per region
declare -A region_instance_count

for REGION in $regions; do
  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceClass' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count["$REGION"]=$instance_count

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+------------------+"
echo ""

# Perform detailed audit for non-compliant regions
non_compliant_found=false
echo "Starting compliance audit..."
for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  instance_types=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceClass' --output text | sort -u)

  instance_type_count=$(echo "$instance_types" | wc -l)

  if [[ "$instance_type_count" -gt 1 ]]; then
    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo "Instance Types Found:"
    echo "$instance_types"
    echo "Status: Non-Compliant - Multiple RDS instance types detected"
    echo "--------------------------------------------------"
    non_compliant_found=true
  fi
done

# Display compliance message if no non-compliance found
if [ "$non_compliant_found" = false ]; then
  echo "All RDS instances in all regions use the same instance type. No non-compliance detected."
fi

echo "Audit completed for all regions."
