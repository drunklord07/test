#!/bin/bash

# Description and Criteria
description="AWS Audit for ElastiCache clusters running outdated Redis or Memcached engine versions."
criteria="Identifies Redis and Memcached clusters that are not using the latest supported engine versions."

# Commands used
command_used="Commands Used:
  1. aws elasticache describe-cache-clusters --region \$REGION --query 'CacheClusters[?(Engine==\`redis\`)].[CacheClusterId, EngineVersion]'
  2. aws elasticache describe-cache-clusters --region \$REGION --query 'CacheClusters[?(Engine==\`memcached\`)].[CacheClusterId, EngineVersion]'"

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

# Define latest engine versions for Redis and Memcached
LATEST_REDIS_VERSION="7.0.5"
LATEST_MEMCACHED_VERSION="1.6.19"

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Total Redis | Total Memcached"
echo "+--------------+------------+----------------+"

declare -A total_redis
declare -A total_memcached
outdated_found=false
outdated_details=()

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

# Step 2: Audit Redis and Memcached Clusters for Outdated Engine Versions
echo "Checking for outdated Redis and Memcached engine versions..."

for REGION in $regions; do
    # Get Redis Clusters and their Engine Versions
    redis_info=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`redis`)].[CacheClusterId, EngineVersion]' --output text 2>/dev/null)

    while read -r CLUSTER_ID ENGINE_VERSION; do
        # Skip empty lines
        [[ -z "$CLUSTER_ID" || -z "$ENGINE_VERSION" ]] && continue

        # Check if the Redis version is outdated
        if [[ "$(printf '%s\n' "$LATEST_REDIS_VERSION" "$ENGINE_VERSION" | sort -V | head -n1)" != "$LATEST_REDIS_VERSION" ]]; then
            outdated_found=true
            outdated_details+=("Region: $REGION | Cluster: $CLUSTER_ID | Engine: Redis | Installed Version: $ENGINE_VERSION | Latest Version: $LATEST_REDIS_VERSION (Upgrade Required)")
        fi
    done <<< "$redis_info"

    # Get Memcached Clusters and their Engine Versions
    memcached_info=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`memcached`)].[CacheClusterId, EngineVersion]' --output text 2>/dev/null)

    while read -r CLUSTER_ID ENGINE_VERSION; do
        # Skip empty lines
        [[ -z "$CLUSTER_ID" || -z "$ENGINE_VERSION" ]] && continue

        # Check if the Memcached version is outdated
        if [[ "$(printf '%s\n' "$LATEST_MEMCACHED_VERSION" "$ENGINE_VERSION" | sort -V | head -n1)" != "$LATEST_MEMCACHED_VERSION" ]]; then
            outdated_found=true
            outdated_details+=("Region: $REGION | Cluster: $CLUSTER_ID | Engine: Memcached | Installed Version: $ENGINE_VERSION | Latest Version: $LATEST_MEMCACHED_VERSION (Upgrade Required)")
        fi
    done <<< "$memcached_info"
done

# Display Audit Results
echo ""
echo "---------------------------------------------------------------------"
echo "Audit Results (Only Outdated Clusters Listed)"
echo "---------------------------------------------------------------------"
if [[ "$outdated_found" == false ]]; then
    echo "All Redis and Memcached clusters are running the latest engine versions. No issues found."
else
    for detail in "${outdated_details[@]}"; do
        echo "$detail"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
