#!/bin/bash

# Description and Criteria
description="AWS Audit for Publicly Accessible RDS Snapshots"
criteria="This script checks all manual RDS snapshots in each AWS region to identify publicly accessible ones. A publicly accessible RDS snapshot allows any AWS account to copy or restore it, posing a security risk."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-snapshots --region \$REGION --snapshot-type manual --query 'DBSnapshots[*].DBSnapshotIdentifier' --output text
  3. aws rds describe-db-snapshot-attributes --region \$REGION --db-snapshot-identifier \$SNAPSHOT --query 'DBSnapshotAttributesResult.DBSnapshotAttributes[?AttributeName==\`restore\`].AttributeValues' --output text"

# Color codes
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
echo "+----------------+----------------------+"
echo "| Region         | Snapshots Found      |"
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
echo "Non-Compliant Snapshots:"
for REGION in "${!region_snapshot_count[@]}"; do
  if [[ "${region_snapshot_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  snapshots=$(aws rds describe-db-snapshots --region "$REGION" --profile "$PROFILE" \
    --snapshot-type manual --query 'DBSnapshots[*].DBSnapshotIdentifier' --output text)

  for SNAPSHOT in $snapshots; do
    # Fetch snapshot attributes
    ATTRIBUTES=$(aws rds describe-db-snapshot-attributes --region "$REGION" --profile "$PROFILE" \
      --db-snapshot-identifier "$SNAPSHOT" \
      --query "DBSnapshotAttributesResult.DBSnapshotAttributes[?AttributeName==\`restore\`].AttributeValues" --output text)

    # Only display non-compliant snapshots
    if echo "$ATTRIBUTES" | grep -q "all"; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Snapshot ID: $SNAPSHOT"
      echo "Restore Permissions: $ATTRIBUTES"
      echo -e "Status: ${RED}Non-Compliant - Publicly Accessible${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
