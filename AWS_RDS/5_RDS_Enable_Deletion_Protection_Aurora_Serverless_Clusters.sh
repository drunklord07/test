#!/bin/bash

# Description and Criteria
description="AWS Audit for Aurora Serverless Clusters - Deletion Protection Check"
criteria="This script checks all Amazon Aurora Serverless clusters in each AWS region to determine if Deletion Protection is enabled. If Deletion Protection is disabled, the cluster is considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-clusters --region \$REGION --query 'DBClusters[?EngineMode==\`serverless\`].DBClusterIdentifier' --output text
  3. aws rds describe-db-clusters --region \$REGION --db-cluster-identifier \$CLUSTER --query 'DBClusters[*].DeletionProtection' --output text"

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

# Table Header for Aurora Serverless Cluster Count
echo "+----------------+----------------------------------+"
echo "| Region         | Aurora Serverless Clusters      |"
echo "+----------------+----------------------------------+"

# Collect cluster count per region
declare -A region_cluster_count

for REGION in $regions; do
  clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?EngineMode==`serverless`].DBClusterIdentifier' --output text)

  cluster_count=$(echo "$clusters" | wc -w)
  region_cluster_count["$REGION"]=$cluster_count

  printf "| %-14s | %-32s |\n" "$REGION" "$cluster_count"
done

echo "+----------------+----------------------------------+"
echo ""

# Perform detailed audit for non-compliant clusters
echo "Non-Compliant Aurora Serverless Clusters (Deletion Protection Disabled):"
for REGION in "${!region_cluster_count[@]}"; do
  if [[ "${region_cluster_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?EngineMode==`serverless`].DBClusterIdentifier' --output text)

  for CLUSTER in $clusters; do
    # Fetch Deletion Protection status
    STATUS=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
      --db-cluster-identifier "$CLUSTER" \
      --query "DBClusters[*].DeletionProtection" --output text)

    # Only display non-compliant clusters
    if [[ "$STATUS" == "False" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Cluster ID: $CLUSTER"
      echo "Deletion Protection: Disabled"
      echo "Status: Non-Compliant"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
