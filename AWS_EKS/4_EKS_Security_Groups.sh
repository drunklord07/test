#!/bin/bash

# Description and Criteria
description="AWS Audit for EKS Security Group Inbound Rules Compliance"
criteria="This script checks whether EKS security groups allow ingress traffic only on TCP port 443 (HTTPS)."

# Commands used
command_used="Commands Used:
  1. aws eks list-clusters --region \$REGION --query 'clusters' --output text
  2. aws eks describe-cluster --region \$REGION --name \$CLUSTER --query 'cluster.resourcesVpcConfig.securityGroupIds' --output text
  3. aws ec2 describe-security-groups --region \$REGION --group-ids \$SG_ID --query 'SecurityGroups[*].IpPermissions' --output json"

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
echo "Region         | Total Clusters | Non-Compliant Clusters"
echo "+--------------+---------------+------------------------+"

declare -A total_clusters
declare -A non_compliant_clusters

# Audit each region
for REGION in $regions; do
  # Get all EKS cluster names
  clusters=$(aws eks list-clusters --region "$REGION" --profile "$PROFILE" --query 'clusters' --output text)

  cluster_count=0
  non_compliant_list=()

  for CLUSTER in $clusters; do
    ((cluster_count++))

    # Get security group IDs for the cluster
    sg_ids=$(aws eks describe-cluster --region "$REGION" --profile "$PROFILE" \
      --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.securityGroupIds' --output text)

    for SG_ID in $sg_ids; do
      # Get security group inbound rules
      ingress_rules=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
        --group-ids "$SG_ID" --query 'SecurityGroups[*].IpPermissions' --output json)

      # Check for non-compliant rules
      if echo "$ingress_rules" | jq -e '.[][] | select(.FromPort != 443 or .ToPort != 443)' > /dev/null; then
        non_compliant_list+=("$CLUSTER ($SG_ID has open ports other than 443)")
      fi
    done
  done

  total_clusters["$REGION"]=$cluster_count
  non_compliant_clusters["$REGION"]=${#non_compliant_list[@]}

  printf "| %-14s | %-15s | %-22s |\n" "$REGION" "$cluster_count" "${#non_compliant_list[@]}"
done

echo "+--------------+---------------+------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_clusters[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant EKS Clusters:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_clusters[@]}"; do
    if [[ "${#non_compliant_clusters[$region]}" -gt 0 ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Clusters:"
      for c in "${non_compliant_clusters[$region]}"; do
        echo " - $c"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All EKS security groups allow only HTTPS (TCP port 443).${NC}"
fi

echo "Audit completed for all regions."
