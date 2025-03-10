#!/bin/bash

# Description and Criteria
description="AWS Audit for Aurora Database Clusters with Database Activity Stream Disabled"
criteria="This script checks all Amazon Aurora database clusters in each AWS region to verify if the Database Activity Stream feature is enabled. Clusters with a 'stopped' status are considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-clusters --region \$REGION --query 'DBClusters[?Engine==\`aurora-mysql\` || Engine==\`aurora-postgresql\`].DBClusterIdentifier | []'
  3. aws rds describe-db-clusters --region \$REGION --db-cluster-identifier \$CLUSTER_ID --query 'DBClusters[*].ActivityStreamStatus'"

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
echo "+----------------+----------------+"
echo "| Region         | Aurora Clusters |"
echo "+----------------+----------------+"

# Collect cluster count per region
declare -A region_cluster_count

for REGION in $regions; do
  clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?Engine==`aurora-mysql` || Engine==`aurora-postgresql`].DBClusterIdentifier | []' \
    --output text)

  cluster_count=$(echo "$clusters" | wc -w)
  region_cluster_count["$REGION"]=$cluster_count

  printf "| %-14s | %-16s |\n" "$REGION" "$cluster_count"
done

echo "+----------------+----------------+"
echo ""

# Perform detailed audit for non-compliant clusters
for REGION in "${!region_cluster_count[@]}"; do
  if [[ "${region_cluster_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  echo "Starting audit for region: $REGION"

  clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?Engine==`aurora-mysql` || Engine==`aurora-postgresql`].DBClusterIdentifier | []' \
    --output text)

  for CLUSTER_ID in $clusters; do
    # Fetch Database Activity Stream status
    ACTIVITY_STATUS=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
      --db-cluster-identifier "$CLUSTER_ID" \
      --query 'DBClusters[*].ActivityStreamStatus' --output text)

    # Report only non-compliant clusters
    if [[ "$ACTIVITY_STATUS" == "stopped" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Cluster ID: $CLUSTER_ID"
      echo "Activity Stream Status: $ACTIVITY_STATUS"
      echo "Status: Non-Compliant - Database Activity Stream is disabled"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
