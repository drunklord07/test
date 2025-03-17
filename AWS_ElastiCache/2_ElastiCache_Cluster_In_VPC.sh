#!/bin/bash

# Description and Criteria
description="AWS Audit for ElastiCache clusters running in EC2-Classic instead of EC2-VPC."
criteria="Identifies Redis and Memcached clusters that do not have an associated VPC subnet group, indicating they are using EC2-Classic."

# Commands used
command_used="Commands Used:
  1. aws elasticache describe-replication-groups --region \$REGION --query 'ReplicationGroups[*].ReplicationGroupId'
  2. aws elasticache describe-cache-clusters --region \$REGION --query 'CacheClusters[*].CacheClusterId'
  3. aws elasticache describe-replication-groups --region \$REGION --replication-group-id <REDIS_GROUP> --query 'ReplicationGroups[*].MemberClusters | []'
  4. aws elasticache describe-cache-clusters --region \$REGION --cache-cluster-id <CLUSTER_ID> --query 'CacheClusters[*].CacheSubnetGroupName'"

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
echo "Region         | Total Redis | Total Memcached"
echo "+--------------+------------+----------------+"

declare -A total_redis
declare -A total_memcached
ec2_classic_found=false
ec2_classic_details=()

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

# Step 2: Audit Redis and Memcached Clusters for EC2-Classic
echo "Checking for ElastiCache clusters running in EC2-Classic..."

for REGION in $regions; do
    # Audit Redis Clusters
    for REDIS_GROUP in $(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --query 'ReplicationGroups[*].ReplicationGroupId' --output text 2>/dev/null); do
        for REDIS_CLUSTER in $(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --replication-group-id "$REDIS_GROUP" --query 'ReplicationGroups[*].MemberClusters[]' --output text 2>/dev/null); do
            subnet_group=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --cache-cluster-id "$REDIS_CLUSTER" --query 'CacheClusters[*].CacheSubnetGroupName' --output text 2>/dev/null)

            if [[ -z "$subnet_group" || "$subnet_group" == "[]" ]]; then
                ec2_classic_found=true
                ec2_classic_details+=("Region: $REGION | Redis Cluster: $REDIS_CLUSTER | Platform: EC2-Classic (No VPC Subnet Group)")
            fi
        done
    done

    # Audit Memcached Clusters
    for MEMCACHED_GROUP in $(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --query 'CacheClusters[?(Engine==`memcached`)].CacheClusterId' --output text 2>/dev/null); do
        subnet_group=$(aws elasticache describe-cache-clusters --region "$REGION" --profile "$PROFILE" --cache-cluster-id "$MEMCACHED_GROUP" --query 'CacheClusters[*].CacheSubnetGroupName' --output text 2>/dev/null)

        if [[ -z "$subnet_group" || "$subnet_group" == "[]" ]]; then
            ec2_classic_found=true
            ec2_classic_details+=("Region: $REGION | Memcached Cluster: $MEMCACHED_GROUP | Platform: EC2-Classic (No VPC Subnet Group)")
        fi
    done
done

# Display Audit Results
echo ""
echo "---------------------------------------------------------------------"
echo "Audit Results (Only Clusters Running in EC2-Classic Listed)"
echo "---------------------------------------------------------------------"
if [[ "$ec2_classic_found" == false ]]; then
    echo "All Redis and Memcached clusters are running within a VPC subnet group. No issues found."
else
    for detail in "${ec2_classic_details[@]}"; do
        echo "$detail"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
