#!/bin/bash

# Description and Criteria
description="AWS Audit for EKS Kubernetes Version Compliance"
criteria="This script checks whether each Amazon EKS cluster is running a supported Kubernetes version. If a cluster is using an extended support version, a warning is issued."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks describe-cluster --region \$REGION --name \$CLUSTER --query 'cluster.version' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
YELLOW='\033[0;33m'
NC='\033[0m'  # No color

# Define supported Kubernetes versions
STANDARD_SUPPORT_VERSIONS=("1.32" "1.31" "1.30" "1.29")
EXTENDED_SUPPORT_VERSIONS=("1.28" "1.27" "1.26" "1.25" "1.24")

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
declare -A warning_clusters

# Audit each region
for REGION in $regions; do
  # Get all EKS clusters
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0
  non_compliant_list=()
  warning_list=()

  for CLUSTER in $clusters; do
    ((cluster_count++))

    # Get Kubernetes version
    kube_version=$(aws eks describe-cluster --region "$REGION" --profile "$PROFILE" \
      --name "$CLUSTER" --query 'cluster.version' --output text)

    if [[ ! " ${STANDARD_SUPPORT_VERSIONS[@]} " =~ " $kube_version " ]] && [[ ! " ${EXTENDED_SUPPORT_VERSIONS[@]} " =~ " $kube_version " ]]; then
      non_compliant_list+=("$CLUSTER (Kubernetes Version: $kube_version - Unsupported)")
    elif [[ " ${EXTENDED_SUPPORT_VERSIONS[@]} " =~ " $kube_version " ]]; then
      warning_list+=("$CLUSTER (Kubernetes Version: $kube_version - Extended Support)")
    fi
  done

  total_clusters["$REGION"]=$cluster_count
  non_compliant_clusters["$REGION"]="${non_compliant_list[@]}"
  warning_clusters["$REGION"]="${warning_list[@]}"

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
fi

if [ ${#warning_clusters[@]} -gt 0 ]; then
  echo -e "${YELLOW}Warning: EKS Clusters Using Extended Support Versions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!warning_clusters[@]}"; do
    if [[ -n "${warning_clusters[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Clusters in Extended Support:"
      for cluster in ${warning_clusters[$region]}; do
        echo " - $cluster"
      done
      echo "----------------------------------------------------------------"
    fi
  done
fi

if [ ${#non_compliant_clusters[@]} -eq 0 ] && [ ${#warning_clusters[@]} -eq 0 ]; then
  echo -e "${GREEN}All EKS clusters are running standard support Kubernetes versions.${NC}"
fi

echo "Audit completed for all regions."
