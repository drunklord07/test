#!/bin/bash

# Description and Criteria
description="AWS Audit for ElastiCache clusters using default ports"
criteria="Identifies Redis and Memcached clusters using default ports (6379 for Redis, 11211 for Memcached), which may pose security risks."

# Commands used
command_used="Commands Used:
  1. aws elasticache describe-replication-groups --region \$REGION --query 'ReplicationGroups[*].ReplicationGroupId'
  2. aws elasticache describe-cache-clusters --region \$REGION --query 'CacheClusters[?(Engine==\`memcached\`)].CacheClusterId'
  3. aws elasticache describe-replication-groups --region \$REGION --replication-group-id <REDIS_GROUP> --query 'ReplicationGroups[*].NodeGroups[*].PrimaryEndpoint.Port[]'
  4. aws elasticache describe-cache-clusters --region \$REGION --cache-cluster-id <MEMCACHED_GROUP> --query 'CacheClusters[*].ConfigurationEndpoint.Port'"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
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
echo "Region         | Total Redis | Total Memcached"
echo "+--------------+------------+----------------+"

declare -A total_redis
declare -A total_memcached
insecure_found=false
insecure_details=()

# Step 1: Count Redis and Memcached Clusters (Fast Execution)
for REGION in $regions; do
    redis_clusters=$(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --query 'ReplicationGroups[*].ReplicationGroupId' --output text 2>/dev/null)
    redis_count=$(echo "$redis_clusters" | wc -w)

    memcached_clusters=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`memcached`)].CacheClusterId' --output text 2>/dev/null)
    memcached_count=$(echo "$memcached_clusters" | wc -w)

    total_redis["$REGION"]=$redis_count
    total_memcached["$REGION"]=$memcached_count

    printf "| %-14s | %-10s | %-14s |\n" "$REGION" "$redis_count" "$memcached_count"
done

echo "+--------------+------------+----------------+"
echo ""

# Step 2: Audit Insecure Redis and Memcached Clusters
echo " Auditing Insecure Redis & Memcached Clusters..."
for REGION in $regions; do
    for REDIS_GROUP in $(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --query 'ReplicationGroups[*].ReplicationGroupId' --output text 2>/dev/null); do
        redis_port=$(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --replication-group-id "$REDIS_GROUP" --query 'ReplicationGroups[*].NodeGroups[*].PrimaryEndpoint.Port[]' --output text 2>/dev/null)

        if [[ "$redis_port" == "6379" ]]; then
            insecure_found=true
            insecure_details+=("Region: $REGION | Redis Cluster: $REDIS_GROUP | Port: 6379 (Insecure)")
        fi
    done

    for MEMCACHED_GROUP in $(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`memcached`)].CacheClusterId' --output text 2>/dev/null); do
        memcached_port=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --cache-cluster-id "$MEMCACHED_GROUP" --query 'CacheClusters[*].ConfigurationEndpoint.Port' --output text 2>/dev/null)

        if [[ "$memcached_port" == "11211" ]]; then
            insecure_found=true
            insecure_details+=("Region: $REGION | Memcached Cluster: $MEMCACHED_GROUP | Port: 11211 (Insecure)")
        fi
    done
done

# Display Audit Results
echo ""
echo "---------------------------------------------------------------------"
echo " Audit Results "
echo "---------------------------------------------------------------------"
if [[ "$insecure_found" == false ]]; then
    echo -e "${GREEN} All Redis and Memcached clusters are using non-default, secure ports. No issues found.${NC}"
else
    for detail in "${insecure_details[@]}"; do
        echo -e "${RED}$detail${NC}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
