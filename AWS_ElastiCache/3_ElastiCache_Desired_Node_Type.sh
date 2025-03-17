#!/bin/bash

# Description and Criteria
description="AWS Audit for ElastiCache clusters not using desired node types."
criteria="Identifies Redis and Memcached clusters with node types that do not match the organization's allowed configurations."

# Commands used
command_used="Commands Used:
  1. aws elasticache describe-cache-clusters --region \$REGION --query 'CacheClusters[*].CacheClusterId'
  2. aws elasticache describe-cache-clusters --region \$REGION --cache-cluster-id <CLUSTER_ID> --query 'CacheClusters[*].[Engine,CacheNodeType]'"

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

# Define allowed node types based on the organization's policy
declare -A allowed_node_types
allowed_node_types["redis"]="cache.t3.micro cache.t3.small cache.m5.large"
allowed_node_types["memcached"]="cache.r5.large cache.m5.large"

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Total Redis | Total Memcached"
echo "+--------------+------------+----------------+"

declare -A total_redis
declare -A total_memcached
non_compliant_found=false
non_compliant_details=()

# Step 1: Count Redis and Memcached Clusters (Fast Execution)
for REGION in $regions; do
    redis_clusters=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`redis`)].CacheClusterId' --output text 2>/dev/null)
    redis_count=$(echo "$redis_clusters" | wc -w)

    memcached_clusters=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`memcached`)].CacheClusterId' --output text 2>/dev/null)
    memcached_count=$(echo "$memcached_clusters" | wc -w)

    total_redis["$REGION"]=$redis_count
    total_memcached["$REGION"]=$memcached_count

    printf "| %-14s | %-10s | %-14s |\n" "$REGION" "$redis_count" "$memcached_count"
done

echo "+--------------+------------+----------------+"
echo ""

# Step 2: Audit Redis and Memcached Clusters for Non-Compliant Node Types
echo "Checking for ElastiCache clusters using non-compliant node types..."

for REGION in $regions; do
    # Audit all ElastiCache clusters in the region
    cluster_info=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[*].[CacheClusterId, Engine, CacheNodeType]' --output text 2>/dev/null)
    
    while read -r CLUSTER_ID ENGINE NODE_TYPE; do
        # Skip empty lines
        [[ -z "$CLUSTER_ID" || -z "$ENGINE" || -z "$NODE_TYPE" ]] && continue

        # Validate node type against allowed configurations
        if [[ ! " ${allowed_node_types[$ENGINE]} " =~ " $NODE_TYPE " ]]; then
            non_compliant_found=true
            non_compliant_details+=("Region: $REGION | Cluster: $CLUSTER_ID | Engine: $ENGINE | Node Type: $NODE_TYPE (Not Allowed)")
        fi
    done <<< "$cluster_info"
done

# Display Audit Results
echo ""
echo "---------------------------------------------------------------------"
echo "Audit Results (Only Non-Compliant Clusters Listed)"
echo "---------------------------------------------------------------------"
if [[ "$non_compliant_found" == false ]]; then
    echo "All Redis and Memcached clusters are using the desired node types. No issues found."
else
    for detail in "${non_compliant_details[@]}"; do
        echo "$detail"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
