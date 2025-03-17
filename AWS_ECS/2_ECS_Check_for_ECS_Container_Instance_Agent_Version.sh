#!/bin/bash

# Description and Criteria
description="AWS Audit for ECS Container Agent Version Compliance"
criteria="Checks if all Amazon ECS container instances are running the latest ECS container agent version."

# Commands used
command_used="Commands Used:
  1. aws ecs list-clusters --region \$REGION --query 'clusterArns'
  2. aws ecs list-container-instances --region \$REGION --cluster <CLUSTER_ARN> --query 'containerInstanceArns'
  3. aws ecs describe-container-instances --region \$REGION --cluster <CLUSTER_ARN> --container-instances <INSTANCE_ARN> --query 'containerInstances[*].versionInfo.agentVersion'"

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

# Get latest ECS agent version
latest_agent_version=$(curl -s https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-agent-update.html | grep -oP '(?<=The latest container agent version is )\d+\.\d+\.\d+' | head -1)

# Table Header (Instant Display)
echo "Region         | Total Clusters | Total Instances | Non-Compliant Instances"
echo "+--------------+---------------+----------------+------------------------+"

declare -A total_clusters
declare -A total_instances
declare -A non_compliant_instances
non_compliant_found=false

# Step 1: Get ECS Clusters
for REGION in $regions; do
    cluster_arns=$(aws ecs list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusterArns' --output text 2>/dev/null)
    cluster_count=$(echo "$cluster_arns" | wc -w)
    instance_count=0
    non_compliant_count=0

    # Step 2: Iterate through ECS Clusters
    for CLUSTER_ARN in $cluster_arns; do
        instance_arns=$(aws ecs list-container-instances --region "$REGION" --profile "$PROFILE" --cluster "$CLUSTER_ARN" --query 'containerInstanceArns' --output text 2>/dev/null)

        # Step 3: Check Container Agent Version
        for INSTANCE_ARN in $instance_arns; do
            agent_version=$(aws ecs describe-container-instances --region "$REGION" --profile "$PROFILE" --cluster "$CLUSTER_ARN" --container-instances "$INSTANCE_ARN" --query 'containerInstances[*].versionInfo.agentVersion' --output text 2>/dev/null)

            ((instance_count++))

            if [[ "$agent_version" < "$latest_agent_version" ]]; then
                ((non_compliant_count++))
                non_compliant_found=true
                echo -e "${RED}Region: $REGION | Cluster: $CLUSTER_ARN | Instance: $INSTANCE_ARN | Agent Version: $agent_version (Outdated)${NC}"
                echo "----------------------------------------------------------------"
            fi
        done
    done

    total_clusters["$REGION"]=$cluster_count
    total_instances["$REGION"]=$instance_count
    non_compliant_instances["$REGION"]=$non_compliant_count
    printf "| %-14s | %-13s | %-14s | %-24s |\n" "$REGION" "$cluster_count" "$instance_count" "$non_compliant_count"
done

echo "+--------------+---------------+----------------+------------------------+"
echo ""

# Final Compliance Check
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All ECS container instances are running the latest ECS agent version. No issues found.${NC}"
fi

echo "Audit completed for all regions."
