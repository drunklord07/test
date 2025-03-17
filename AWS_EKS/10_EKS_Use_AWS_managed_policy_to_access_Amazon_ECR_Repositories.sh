#!/bin/bash

# Description and Criteria
description="AWS Audit for EKS Node Group IAM Role - Amazon ECR Read Access"
criteria="This script checks if the AmazonEC2ContainerRegistryReadOnly policy is attached to each EKS cluster node group IAM role."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks list-nodegroups --region \$REGION --cluster-name \$CLUSTER --query 'nodegroups' --output text
  3. aws eks describe-nodegroup --region \$REGION --cluster-name \$CLUSTER --nodegroup-name \$NODEGROUP --query 'nodegroup.nodeRole' --output text
  4. aws iam list-attached-role-policies --role-name \$ROLE_NAME --query 'AttachedPolicies[*].PolicyArn' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Required policy
REQUIRED_POLICY="arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

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
echo "Region         | Total EKS Clusters | Non-Compliant Node Groups"
echo "+--------------+-------------------+---------------------------+"

declare -A total_clusters
declare -A non_compliant_nodegroups

# Audit each region
for REGION in $regions; do
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0
  non_compliant_list=()

  for CLUSTER in $clusters; do
    ((cluster_count++))

    nodegroups=$(aws eks list-nodegroups --region "$REGION" --profile "$PROFILE" --cluster-name "$CLUSTER" --query 'nodegroups' --output text)

    for NODEGROUP in $nodegroups; do
      # Get IAM role of node group
      node_role=$(aws eks describe-nodegroup --region "$REGION" --profile "$PROFILE" --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" --query 'nodegroup.nodeRole' --output text)
      role_name=$(basename "$node_role")

      # Get attached policies
      policies=$(aws iam list-attached-role-policies --profile "$PROFILE" --role-name "$role_name" --query 'AttachedPolicies[*].PolicyArn' --output text)

      if [[ ! " ${policies[@]} " =~ " $REQUIRED_POLICY " ]]; then
        non_compliant_list+=("$CLUSTER / $NODEGROUP (IAM Role: $role_name - Missing AmazonEC2ContainerRegistryReadOnly)")
      fi
    done
  done

  total_clusters["$REGION"]=$cluster_count
  non_compliant_nodegroups["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-19s | %-27s |\n" "$REGION" "$cluster_count" "${#non_compliant_list[@]}"
done

echo "+--------------+-------------------+---------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_nodegroups[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant EKS Node Groups:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_nodegroups[@]}"; do
    if [[ -n "${non_compliant_nodegroups[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Node Groups:"
      for nodegroup in ${non_compliant_nodegroups[$region]}; do
        echo " - $nodegroup"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All EKS node groups have the required AmazonEC2ContainerRegistryReadOnly policy.${NC}"
fi

echo "Audit completed for all regions."
