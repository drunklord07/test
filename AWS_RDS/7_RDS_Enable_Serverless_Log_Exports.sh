#!/bin/bash

# Description and Criteria
description="AWS Audit for Aurora Serverless Clusters - CloudWatch Log Exports"
criteria="This script checks all Amazon Aurora Serverless clusters in each AWS region to verify if CloudWatch log exports are enabled. Clusters with no logs configured are considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-clusters --region \$REGION --query 'DBClusters[?Engine==\`aurora\` && EngineMode==\`serverless\`].DBClusterIdentifier | []'
  3. aws rds describe-db-clusters --region \$REGION --db-cluster-identifier \$CLUSTER_ID --query 'DBClusters[*].EnabledCloudwatchLogsExports'"

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
echo "| Region         | Serverless Clusters  |"
echo "+----------------+----------------------+"

# Collect cluster count per region
declare -A region_cluster_count

for REGION in $regions; do
  clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?Engine==`aurora` && EngineMode==`serverless`].DBClusterIdentifier' --output text)

  cluster_count=$(echo "$clusters" | wc -w)
  region_cluster_count["$REGION"]=$cluster_count

  printf "| %-14s | %-20s |\n" "$REGION" "$cluster_count"
done

echo "+----------------+----------------------+"
echo ""

# Perform detailed audit for non-compliant clusters
non_compliant_found=false
echo "Starting compliance audit..."
for REGION in "${!region_cluster_count[@]}"; do
  if [[ "${region_cluster_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
    --query 'DBClusters[?Engine==`aurora` && EngineMode==`serverless`].DBClusterIdentifier' --output text)

  for CLUSTER_ID in $clusters; do
    # Fetch enabled log exports
    LOG_EXPORTS=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" \
      --db-cluster-identifier "$CLUSTER_ID" \
      --query "DBClusters[*].EnabledCloudwatchLogsExports" --output text)

    # Check if logs are not enabled (empty output)
    if [[ -z "$LOG_EXPORTS" || "$LOG_EXPORTS" == "None" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Cluster ID: $CLUSTER_ID"
      echo "CloudWatch Log Exports: None"
      echo "Status: Non-Compliant - No logs exported to CloudWatch"
      echo "--------------------------------------------------"
      non_compliant_found=true
    fi
  done
done

# Display compliance message if no non-compliance found
if [ "$non_compliant_found" = false ]; then
  echo "No non-compliant Aurora Serverless clusters found."
fi

echo "Audit completed for all regions."
