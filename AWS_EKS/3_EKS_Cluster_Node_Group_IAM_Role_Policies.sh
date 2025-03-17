#!/bin/bash

# Description and Criteria
description="AWS Audit for EKS Cluster Node Group IAM Role Permissions"
criteria="This script checks if EKS cluster node group IAM roles have overly permissive policies attached."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks list-nodegroups --region \$REGION --cluster-name \$CLUSTER --query 'nodegroups' --output text
  3. aws eks describe-nodegroup --region \$REGION --cluster-name \$CLUSTER --nodegroup-name \$NODEGROUP --query 'nodegroup.nodeRole' --output text
  4. aws iam list-attached-role-policies --role-name \$ROLE --query 'AttachedPolicies[*].PolicyArn' --output text
  5. aws iam list-role-policies --role-name \$ROLE --query 'PolicyNames' --output text"

# Allowed policies
allowed_policies=(
  "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
)

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
echo "Region         | Total Clusters"
echo "+--------------+---------------+"

declare -A total_clusters

# Audit each region
for REGION in $regions; do
  # Get all EKS clusters
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0

  for CLUSTER in $clusters; do
    ((cluster_count++))
    
    # Get all node groups for the cluster
    nodegroups=$(aws eks list-nodegroups --region "$REGION" --profile "$PROFILE" --cluster-name "$CLUSTER" --query 'nodegroups' --output text)

    for NODEGROUP in $nodegroups; do
      # Get IAM role for the node group
      role_arn=$(aws eks describe-nodegroup --region "$REGION" --profile "$PROFILE" --cluster-name "$CLUSTER" --nodegroup-name "$NODEGROUP" --query 'nodegroup.nodeRole' --output text)
      
      # Extract IAM role name
      role_name=$(echo "$role_arn" | awk -F'/' '{print $NF}')
      
      # Get attached IAM policies
      attached_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyArn' --output text)

      for policy in $attached_policies; do
        if [[ ! " ${allowed_policies[@]} " =~ " $policy " ]]; then
          echo -e "${RED}Non-compliant IAM policy detected: $policy attached to role $role_name in cluster $CLUSTER (Region: $REGION)${NC}"
        fi
      done
      
      # Get inline policies
      inline_policies=$(aws iam list-role-policies --role-name "$role_name" --profile "$PROFILE" --query 'PolicyNames' --output text)

      if [[ -n "$inline_policies" ]]; then
        echo -e "${GREEN}Inline policies detected for role $role_name in cluster $CLUSTER (Region: $REGION), but they are not necessarily non-compliant.${NC}"
      fi
    done
  done

  total_clusters["$REGION"]=$cluster_count
  printf "| %-14s | %-13s |\n" "$REGION" "$cluster_count"
done

echo "+--------------+---------------+"
echo ""
echo "Audit completed for all regions."
