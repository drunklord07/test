#!/bin/bash

# Description and Criteria
description="AWS Audit for Remote Access to EKS Cluster Node Groups"
criteria="This script checks if remote access (SSH) is enabled for EKS cluster node groups."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks list-nodegroups --region \$REGION --cluster-name \$CLUSTER --query 'nodegroups' --output text
  3. aws eks describe-nodegroup --region \$REGION --cluster-name \$CLUSTER --nodegroup-name \$NODEGROUP --query 'nodegroup.remoteAccess.ec2SshKey' --output text"

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
echo "Region         | Total Clusters | Total Node Groups"
echo "+--------------+---------------+-------------------+"

declare -A total_clusters
declare -A total_nodegroups
declare -A non_compliant_nodegroups

# Audit each region
for REGION in $regions; do
  # Get all EKS clusters
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0
  nodegroup_count=0
  non_compliant_list=()

  for CLUSTER in $clusters; do
    ((cluster_count++))

    # Get all node groups for the cluster
    nodegroups=$(aws eks list-nodegroups --region "$REGION" --profile "$PROFILE" --cluster-name "$CLUSTER" --query 'nodegroups' --output text)

    for NODEGROUP in $nodegroups; do
      ((nodegroup_count++))

      # Check if SSH remote access is enabled
      ssh_key=$(aws eks describe-nodegroup --region "$REGION" --profile "$PROFILE" \
        --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" --query 'nodegroup.remoteAccess.ec2SshKey' --output text)

      if [[ "$ssh_key" != "None" ]]; then
        non_compliant_list+=("$CLUSTER - $NODEGROUP ($ssh_key)")
      fi
    done
  done

  total_clusters["$REGION"]=$cluster_count
  total_nodegroups["$REGION"]=$nodegroup_count
  non_compliant_nodegroups["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-13s | %-17s |\n" "$REGION" "$cluster_count" "$nodegroup_count"
done

echo "+--------------+---------------+-------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_nodegroups[@]} -gt 0 ]; then
  echo -e "${RED}EKS Node Groups with Remote Access Enabled:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_nodegroups[@]}"; do
    if [[ "${#non_compliant_nodegroups[$region]}" -gt 0 ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-compliant Node Groups:"
      for nodegroup in ${non_compliant_nodegroups[$region]}; do
        echo " - $nodegroup"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All EKS Node Groups have remote access disabled.${NC}"
fi

echo "Audit completed for all regions."
