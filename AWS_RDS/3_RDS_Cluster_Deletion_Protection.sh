#!/bin/bash

# Description and Criteria
description="AWS Audit for Aurora Database Clusters with Deletion Protection Disabled"
criteria="This script checks all Amazon Aurora database clusters in each AWS region to verify if the Deletion Protection feature is enabled. Clusters with 'false' status are considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-clusters --region \$REGION --query 'DBClusters[?Engine==\`aurora-mysql\` || Engine==\`aurora-postgresql\`].DBClusterIdentifier | []'
  3. aws rds describe-db-clusters --region \$REGION --db-cluster-identifier \$CLUSTER_ID --query 'DBClusters[*].DeletionProtection'"

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
  cluster_ids=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?Engine==`aurora-mysql` || Engine==`aurora-postgresql`].DBClusterIdentifier | []' --output text)

  cluster_count=$(echo "$cluster_ids" | wc -w)
  region_cluster_count["$REGION"]=$cluster_count

  printf "| %-14s | %-16s |\n" "$REGION" "$cluster_count"
done

echo "+----------------+----------------+"
echo ""

# Perform detailed audit per cluster (only non-compliant clusters)
for REGION in "${!region_cluster_count[@]}"; do
  if [[ "${region_cluster_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  cluster_ids=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?Engine==`aurora-mysql` || Engine==`aurora-postgresql`].DBClusterIdentifier | []' --output text)

  for CLUSTER_ID in $cluster_ids; do
    # Fetch Deletion Protection status
    DELETION_PROTECTION=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
      --db-cluster-identifier "$CLUSTER_ID" \
      --query "DBClusters[*].DeletionProtection" --output text)

    # Only display non-compliant clusters
    if [[ "$DELETION_PROTECTION" == "False" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Cluster ID: $CLUSTER_ID"
      echo "Deletion Protection: false"
      echo "Status: Non-Compliant - Deletion Protection is disabled"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
