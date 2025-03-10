#!/bin/bash

# Description and Criteria
description="AWS Audit for Total Number of RDS Instances (Including Read Replicas)"
criteria="This script counts all Amazon RDS database instances, including Read Replicas, across all AWS regions. If the total number exceeds 10, action is recommended."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[*].[DBInstanceIdentifier,ReadReplicaDBInstanceIdentifiers]'"

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

# Track total number of RDS instances
total_instances=0
declare -A region_instance_count

for REGION in $regions; do
  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].[DBInstanceIdentifier, ReadReplicaDBInstanceIdentifiers]' --output json)

  instance_count=$(echo "$instances" | grep -o '"' | wc -l)
  instance_count=$((instance_count / 2))  # Each instance has a name and an empty array

  region_instance_count["$REGION"]=$instance_count
  total_instances=$((total_instances + instance_count))

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+------------------+"
echo ""
echo "Total RDS Instances Across All Regions: $total_instances"
echo ""

# Check if the total exceeds the recommended limit
if [ "$total_instances" -gt 10 ]; then
  echo "WARNING: The total number of RDS instances exceeds the recommended limit of 10."
  echo "Action: Consider raising an AWS support case to set a limit on the number of RDS instances."
else
  echo "The total number of RDS instances is within the recommended limit."
fi

echo "Audit completed for all regions."
