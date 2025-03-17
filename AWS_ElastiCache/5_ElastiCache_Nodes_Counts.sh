#!/bin/bash

# Description and Criteria
description="AWS Audit for total provisioned ElastiCache nodes (Redis & Memcached) per region."
criteria="Identifies regions where the total number of ElastiCache nodes exceeds the default threshold of 5 nodes per AWS account."

# Commands used
command_used="Commands Used:
  aws elasticache describe-cache-clusters --region \$REGION --query 'CacheClusters[*].[Engine, NumCacheNodes]'"

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

# Define node limit quota (Default: 5 nodes per AWS account)
NODE_LIMIT=5

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Total Redis Nodes | Total Memcached Nodes | Total Nodes"
echo "+--------------+-----------------+---------------------+------------+"

declare -A total_redis_nodes
declare -A total_memcached_nodes
declare -A total_nodes
exceeding_regions=()

# Step 1: Fetch Total Redis and Memcached Nodes Per Region
for REGION in $regions; do
    node_data=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[*].[Engine, NumCacheNodes]' --output text 2>/dev/null)

    redis_nodes=0
    memcached_nodes=0

    while read -r ENGINE NODE_COUNT; do
        [[ -z "$ENGINE" || -z "$NODE_COUNT" ]] && continue
        if [[ "$ENGINE" == "redis" ]]; then
            redis_nodes=$((redis_nodes + NODE_COUNT))
        elif [[ "$ENGINE" == "memcached" ]]; then
            memcached_nodes=$((memcached_nodes + NODE_COUNT))
        fi
    done <<< "$node_data"

    total_redis_nodes["$REGION"]=$redis_nodes
    total_memcached_nodes["$REGION"]=$memcached_nodes
    total_nodes["$REGION"]=$((redis_nodes + memcached_nodes))

    # Check if the total nodes exceed the default threshold
    if [[ ${total_nodes["$REGION"]} -gt $NODE_LIMIT ]]; then
        exceeding_regions+=("$REGION | Total Nodes: ${total_nodes["$REGION"]} (Exceeds Limit of $NODE_LIMIT)")
    fi

    printf "| %-14s | %-17s | %-19s | %-10s |\n" "$REGION" "$redis_nodes" "$memcached_nodes" "${total_nodes["$REGION"]}"
done

echo "+--------------+-----------------+---------------------+------------+"
echo ""

# Step 2: Audit for Exceeded Quotas
echo "---------------------------------------------------------------------"
echo "Audit Results (Regions Exceeding Node Limit Quota: $NODE_LIMIT nodes per AWS account)"
echo "---------------------------------------------------------------------"
if [[ ${#exceeding_regions[@]} -eq 0 ]]; then
    echo "All regions are within the allowed ElastiCache node quota of $NODE_LIMIT nodes."
else
    for detail in "${exceeding_regions[@]}"; do
        echo "$detail"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
