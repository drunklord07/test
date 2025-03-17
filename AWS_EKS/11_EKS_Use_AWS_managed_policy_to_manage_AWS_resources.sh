#!/bin/bash

# Description and Criteria
description="AWS Audit for EKS Cluster IAM Role - AmazonEKSClusterPolicy Compliance"
criteria="This script checks if the AmazonEKSClusterPolicy is attached to each Amazon EKS cluster IAM role."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks describe-cluster --region \$REGION --cluster-name \$CLUSTER --query 'cluster.roleArn' --output text
  3. aws iam list-attached-role-policies --role-name \$ROLE_NAME --query 'AttachedPolicies[*].PolicyArn' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Required policy
REQUIRED_POLICY="arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

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
echo "Region         | Total EKS Clusters "
echo "+--------------+-------------------+"

declare -A total_clusters
declare -A non_compliant_clusters

# Audit each region
for REGION in $regions; do
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0
  non_compliant_list=()

  for CLUSTER in $clusters; do
    ((cluster_count++))

    # Get IAM role of EKS cluster
    cluster_role=$(aws eks describe-cluster --region "$REGION" --profile "$PROFILE" --cluster-name "$CLUSTER" --query 'cluster.roleArn' --output text)
    role_name=$(basename "$cluster_role")

    # Get attached policies
    policies=$(aws iam list-attached-role-policies --profile "$PROFILE" --role-name "$role_name" --query 'AttachedPolicies[*].PolicyArn' --output text)

    if [[ ! " ${policies[@]} " =~ " $REQUIRED_POLICY " ]]; then
      non_compliant_list+=("$CLUSTER (IAM Role: $role_name - Missing AmazonEKSClusterPolicy)")
    fi
  done

  total_clusters["$REGION"]=$cluster_count
  non_compliant_clusters["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-19s |\n" "$REGION" "$cluster_count"
done

echo "+--------------+-------------------+"
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
  echo -e "${GREEN}All EKS clusters have the required AmazonEKSClusterPolicy.${NC}"
fi

echo "Audit completed for all regions."
