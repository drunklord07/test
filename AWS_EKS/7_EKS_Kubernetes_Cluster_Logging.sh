#!/bin/bash

# Description and Criteria
description="AWS Audit for EKS Control Plane Logging Configuration"
criteria="This script checks whether control plane logging is enabled for each Amazon EKS cluster."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks describe-cluster --region \$REGION --name \$CLUSTER --query 'cluster.logging.clusterLogging[*].enabled' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
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
echo "Region         | Total EKS Clusters"
echo "+--------------+------------------+"

declare -A total_clusters
declare -A non_compliant_clusters

# Audit each region
for REGION in $regions; do
  # Get all EKS clusters
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0
  non_compliant_list=()

  for CLUSTER in $clusters; do
    ((cluster_count++))

    # Get control plane logging status
    logging_enabled=$(aws eks describe-cluster --region "$REGION" --profile "$PROFILE" \
      --name "$CLUSTER" --query 'cluster.logging.clusterLogging[*].enabled' --output text)

    if [[ -z "$logging_enabled" || "$logging_enabled" == "None" || "$logging_enabled" == "False" ]]; then
      non_compliant_list+=("$CLUSTER (Control Plane Logging Disabled)")
    fi
  done

  total_clusters["$REGION"]=$cluster_count
  non_compliant_clusters["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-16s |\n" "$REGION" "$cluster_count"
done

echo "+--------------+------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_clusters[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant EKS Clusters:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_clusters[@]}"; do
    if [[ -n "${non_compliant_clusters[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Clusters:"
      for cluster in ${non_compliant_clusters[$region]}; do
        echo " - $cluster"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All EKS clusters have control plane logging enabled.${NC}"
fi

echo "Audit completed for all regions."
