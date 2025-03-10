#!/bin/bash

# Description and Criteria
description="AWS EBS Snapshot Public Access Audit"
criteria="This script lists all EBS snapshots across multiple AWS regions and checks if they are publicly accessible.
If a snapshot is publicly accessible, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-snapshots --region \$REGION --filters Name=status,Values=completed --query 'Snapshots[*].SnapshotId'
  3. aws ec2 describe-snapshot-attribute --region \$REGION --snapshot-id \$snapshot_id --attribute createVolumePermission --query 'CreateVolumePermissions[*]'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display description, criteria, and the command being used
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
echo "\n+----------------+-----------------+"
echo "| Region        | Total Snapshots |"
echo "+----------------+-----------------+"

# Loop through each region and count EBS snapshots
declare -A region_snapshot_count
for REGION in $regions; do
  snapshot_count=$(aws ec2 describe-snapshots --region "$REGION" --profile "$PROFILE" --filters Name=status,Values=completed --query 'length(Snapshots)' --output text)
  region_snapshot_count[$REGION]=$snapshot_count
  printf "| %-14s | %-15s |\n" "$REGION" "$snapshot_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with snapshots
for REGION in "${!region_snapshot_count[@]}"; do
  if [ "${region_snapshot_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    snapshots=$(aws ec2 describe-snapshots --region "$REGION" --profile "$PROFILE" --filters Name=status,Values=completed --query 'Snapshots[*].SnapshotId' --output text)

    while read -r snapshot_id; do
      permissions=$(aws ec2 describe-snapshot-attribute --region "$REGION" --profile "$PROFILE" --snapshot-id "$snapshot_id" --attribute createVolumePermission --query 'CreateVolumePermissions[*].Group' --output text)

      echo "--------------------------------------------------"
      echo "Snapshot ID: $snapshot_id"

      if [[ "$permissions" == "all" ]]; then
        echo -e "Status: ${RED}Non-Compliant (Publicly Accessible)${NC}"
      else
        echo -e "Status: ${GREEN}Compliant (Private)${NC}"
      fi
    done <<< "$snapshots"

    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AWS EBS Snapshots."
