#!/bin/bash

# Description and Criteria
description="AWS Audit for ECS Fargate Platform Version Compliance"
criteria="Checks if all Amazon ECS services using Fargate are running the latest supported platform version."

# Commands used
command_used="Commands Used:
  1. aws ecs list-clusters --region \$REGION --query 'clusterArns'
  2. aws ecs list-services --region \$REGION --cluster <CLUSTER_ARN> --query 'serviceArns'
  3. aws ecs describe-services --region \$REGION --cluster <CLUSTER_ARN> --services <SERVICE_ARN> --query 'services[*].platformVersion'"

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

# Set latest Fargate platform versions
latest_linux_version="1.4.0"
latest_windows_version="1.0.0"

# Table Header (Instant Display)
echo "Region         | Total Clusters | Total Services | Non-Compliant Services"
echo "+--------------+---------------+---------------+------------------------+"

declare -A total_clusters
declare -A total_services
declare -A non_compliant_services
non_compliant_found=false

# Step 1: Get ECS Clusters
for REGION in $regions; do
    cluster_arns=$(aws ecs list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusterArns' --output text 2>/dev/null)
    cluster_count=$(echo "$cluster_arns" | wc -w)
    service_count=0
    non_compliant_count=0

    # Step 2: Iterate through ECS Clusters
    for CLUSTER_ARN in $cluster_arns; do
        service_arns=$(aws ecs list-services --region "$REGION" --profile "$PROFILE" --cluster "$CLUSTER_ARN" --query 'serviceArns' --output text 2>/dev/null)

        # Step 3: Check Fargate Platform Version
        for SERVICE_ARN in $service_arns; do
            platform_version=$(aws ecs describe-services --region "$REGION" --profile "$PROFILE" --cluster "$CLUSTER_ARN" --services "$SERVICE_ARN" --query 'services[*].platformVersion' --output text 2>/dev/null)

            ((service_count++))

            if [[ "$platform_version" != "LATEST" && "$platform_version" < "$latest_linux_version" ]]; then
                ((non_compliant_count++))
                non_compliant_found=true
                echo -e "${RED}Region: $REGION | Cluster: $CLUSTER_ARN | Service: $SERVICE_ARN | Platform Version: $platform_version (Outdated)${NC}"
                echo "----------------------------------------------------------------"
            fi
        done
    done

    total_clusters["$REGION"]=$cluster_count
    total_services["$REGION"]=$service_count
    non_compliant_services["$REGION"]=$non_compliant_count
    printf "| %-14s | %-13s | %-14s | %-24s |\n" "$REGION" "$cluster_count" "$service_count" "$non_compliant_count"
done

echo "+--------------+---------------+---------------+------------------------+"
echo ""

# Final Compliance Check
if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All ECS services are running the latest Fargate platform version. No issues found.${NC}"
fi

echo "Audit completed for all regions."
