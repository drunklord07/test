#!/bin/bash

# Description and Criteria
description="AWS Audit for ElastiCache Redis replication groups to check At-Rest and In-Transit encryption status."
criteria="Identifies Redis clusters where both At-Rest and In-Transit encryption are disabled, which is a security risk."

# Commands used
command_used="Commands Used:
  aws elasticache describe-replication-groups --region \$REGION --query 'ReplicationGroups[*].[ReplicationGroupId]'
  aws elasticache describe-replication-groups --region \$REGION --replication-group-id <group_id> --query 'ReplicationGroups[*].[AtRestEncryptionEnabled, TransitEncryptionEnabled]'"

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
echo "Region         | Redis Cluster ID                     | At-Rest Encryption | In-Transit Encryption"
echo "+--------------+-----------------------------------+------------------+-------------------+"

declare -A non_compliant_clusters

# Step 1: Fetch Redis Replication Groups Per Region
for REGION in $regions; do
    redis_clusters=$(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --query 'ReplicationGroups[*].ReplicationGroupId' --output text 2>/dev/null)

    if [[ -z "$redis_clusters" ]]; then
        continue
    fi

    for GROUP_ID in $redis_clusters; do
        encryption_data=$(aws elasticache describe-replication-groups --region "$REGION" --profile "$PROFILE" --replication-group-id "$GROUP_ID" --query 'ReplicationGroups[*].[AtRestEncryptionEnabled, TransitEncryptionEnabled]' --output text 2>/dev/null)

        at_rest=$(echo "$encryption_data" | awk '{print $1}')
        in_transit=$(echo "$encryption_data" | awk '{print $2}')

        [[ "$at_rest" == "None" ]] && at_rest="false"
        [[ "$in_transit" == "None" ]] && in_transit="false"

        if [[ "$at_rest" == "False" && "$in_transit" == "False" ]]; then
            non_compliant_clusters["$REGION|$GROUP_ID"]="At-Rest: $at_rest, In-Transit: $in_transit"
        fi

        printf "| %-14s | %-33s | %-16s | %-17s |\n" "$REGION" "$GROUP_ID" "$at_rest" "$in_transit"
    done
done

echo "+--------------+-----------------------------------+------------------+-------------------+"
echo ""

# Step 2: Audit for Non-Compliant Clusters
echo "---------------------------------------------------------------------"
echo "Audit Results (Redis clusters where both encryptions are disabled)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_clusters[@]} -eq 0 ]]; then
    echo "All Redis replication groups have at least one encryption feature enabled."
else
    for key in "${!non_compliant_clusters[@]}"; do
        IFS="|" read -r REGION GROUP_ID <<< "$key"
        echo "$REGION | Redis Cluster ID: $GROUP_ID | ${non_compliant_clusters[$key]}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
