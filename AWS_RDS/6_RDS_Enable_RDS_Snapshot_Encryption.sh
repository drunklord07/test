#!/bin/bash

# Description and Criteria
description="AWS Audit for Manual RDS Snapshots - Encryption Status Check"
criteria="This script checks all manual Amazon RDS database snapshots in each AWS region to determine if they are encrypted at rest. If a snapshot is unencrypted, it is considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-snapshots --region \$REGION --snapshot-type manual --query 'DBSnapshots[*].DBSnapshotIdentifier'
  3. aws rds describe-db-snapshots --region \$REGION --db-snapshot-identifier \$SNAPSHOT_ID --query 'DBSnapshots[*].Encrypted'"

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
echo "+----------------+----------------------+"
echo "| Region         | Manual Snapshots     |"
echo "+----------------+----------------------+"

# Collect snapshot count per region
declare -A region_snapshot_count

for REGION in $regions; do
  snapshots=$(aws rds describe-db-snapshots --region "$REGION" --profile "$PROFILE" \
    --snapshot-type manual --query 'DBSnapshots[*].DBSnapshotIdentifier' --output text)

  snapshot_count=$(echo "$snapshots" | wc -w)
  region_snapshot_count["$REGION"]=$snapshot_count

  printf "| %-14s | %-20s |\n" "$REGION" "$snapshot_count"
done

echo "+----------------+----------------------+"
echo ""

# Perform detailed audit for non-compliant snapshots
echo "Starting detailed audit..."

for REGION in "${!region_snapshot_count[@]}"; do
  if [[ "${region_snapshot_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  snapshots=$(aws rds describe-db-snapshots --region "$REGION" --profile "$PROFILE" \
    --snapshot-type manual --query 'DBSnapshots[*].DBSnapshotIdentifier' --output text)

  for SNAPSHOT in $snapshots; do
    # Fetch encryption status
    ENCRYPTION_STATUS=$(aws rds describe-db-snapshots --region "$REGION" --profile "$PROFILE" \
      --db-snapshot-identifier "$SNAPSHOT" --query "DBSnapshots[*].Encrypted" --output text)

    # Only display non-compliant snapshots
    if [[ "$ENCRYPTION_STATUS" == "False" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Snapshot ID: $SNAPSHOT"
      echo "Encryption Status: $ENCRYPTION_STATUS"
      echo "Status: Non-Compliant - Snapshot is not encrypted"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
