#!/bin/bash

# Description and Criteria
description="AWS Audit for Neptune database clusters to check IAM Database Authentication status."
criteria="Identifies Neptune clusters where IAM Database Authentication is disabled, which is a security risk."

# Commands used
command_used="Commands Used:
  aws neptune describe-db-clusters --region \$REGION --query 'DBClusters[*].DBClusterIdentifier'
  aws neptune describe-db-clusters --region \$REGION --db-cluster-identifier <cluster_id> --query 'DBClusters[*].IAMDatabaseAuthenticationEnabled'"

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
echo "Region         | Number of Neptune Clusters"
echo "+--------------+--------------------------+"

declare -A region_cluster_count
declare -A non_compliant_clusters

# Step 1: Fetch Neptune Clusters Per Region
for REGION in $regions; do
    neptune_clusters=$(aws neptune describe-db-clusters --region "$REGION" --profile "$PROFILE" --query 'DBClusters[*].DBClusterIdentifier' --output text 2>/dev/null)

    if [[ -z "$neptune_clusters" ]]; then
        continue
    fi

    cluster_count=0
    for CLUSTER_ID in $neptune_clusters; do
        ((cluster_count++))
        iam_auth_status=$(aws neptune describe-db-clusters --region "$REGION" --profile "$PROFILE" --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[*].IAMDatabaseAuthenticationEnabled' --output text 2>/dev/null)

        [[ "$iam_auth_status" == "None" ]] && iam_auth_status="false"

        if [[ "$iam_auth_status" == "False" ]]; then
            non_compliant_clusters["$REGION|$CLUSTER_ID"]="IAM Authentication: $iam_auth_status"
        fi
    done

    region_cluster_count["$REGION"]=$cluster_count
    printf "| %-14s | %-24s |\n" "$REGION" "$cluster_count"
done

echo "+--------------+--------------------------+"
echo ""

# Step 2: Audit for Non-Compliant Clusters
echo "---------------------------------------------------------------------"
echo "Audit Results (Neptune clusters where IAM Authentication is disabled)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_clusters[@]} -eq 0 ]]; then
    echo "All Neptune clusters have IAM Database Authentication enabled."
else
    for key in "${!non_compliant_clusters[@]}"; do
        IFS="|" read -r REGION CLUSTER_ID <<< "$key"
        echo "$REGION | Neptune Cluster ID: $CLUSTER_ID | ${non_compliant_clusters[$key]}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
