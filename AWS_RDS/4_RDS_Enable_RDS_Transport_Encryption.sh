#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS Instances and Aurora Clusters SSL Enforcement"
criteria="This script checks all Amazon RDS instances and Amazon Aurora clusters in each AWS region to verify if the rds.force_ssl or require_secure_transport parameter is enabled. Resources with '0', 'OFF', or missing values are considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceIdentifier'
  3. aws rds describe-db-instances --region \$REGION --db-instance-identifier \$INSTANCE_ID --query 'DBInstances[*].DBParameterGroups[*].DBParameterGroupName[]'
  4. aws rds describe-db-parameters --region \$REGION --db-parameter-group-name \$PARAM_GROUP --query 'Parameters[?(ParameterName==\`rds.force_ssl\` || ParameterName==\`require_secure_transport\`)]'
  5. aws rds describe-db-clusters --region \$REGION --query 'DBClusters[*].DBClusterIdentifier'
  6. aws rds describe-db-clusters --region \$REGION --db-cluster-identifier \$CLUSTER_ID --query 'DBClusters[*].DBClusterParameterGroup'
  7. aws rds describe-db-cluster-parameters --region \$REGION --db-cluster-parameter-group-name \$PARAM_GROUP --query 'Parameters[?(ParameterName==\`rds.force_ssl\` || ParameterName==\`require_secure_transport\`)]'"

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

# Table Headers
echo "+----------------+----------------+"
echo "| Region         | RDS Instances  |"
echo "+----------------+----------------+"

declare -A region_rds_count
declare -A region_aurora_count

# Collect RDS instance count per region
for REGION in $regions; do
  rds_instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" --query 'DBInstances[*].DBInstanceIdentifier' --output text)
  rds_count=$(echo "$rds_instances" | wc -w)
  region_rds_count["$REGION"]=$rds_count

  printf "| %-14s | %-16s |\n" "$REGION" "$rds_count"
done

echo "+----------------+----------------+"
echo ""

echo "+----------------+----------------+"
echo "| Region         | Aurora Clusters |"
echo "+----------------+----------------+"

# Collect Aurora cluster count per region
for REGION in $regions; do
  aurora_clusters=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" --query 'DBClusters[*].DBClusterIdentifier' --output text)
  aurora_count=$(echo "$aurora_clusters" | wc -w)
  region_aurora_count["$REGION"]=$aurora_count

  printf "| %-14s | %-16s |\n" "$REGION" "$aurora_count"
done

echo "+----------------+----------------+"
echo ""

# RDS Instance Audit (only non-compliant instances)
echo "RDS Instance Audit Results"
echo "--------------------------------------------------"

for REGION in "${!region_rds_count[@]}"; do
  if [[ "${region_rds_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  echo "Checking region: $REGION"
  
  for INSTANCE_ID in $(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" --query 'DBInstances[*].DBInstanceIdentifier' --output text); do
    PARAM_GROUP=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" --db-instance-identifier "$INSTANCE_ID" --query 'DBInstances[*].DBParameterGroups[*].DBParameterGroupName[]' --output text)
    
    if [[ -z "$PARAM_GROUP" ]]; then
      continue
    fi

    SSL_STATUS=$(aws rds describe-db-parameters --region "$REGION" --profile "$PROFILE" --db-parameter-group-name "$PARAM_GROUP" --query 'Parameters[?(ParameterName==`rds.force_ssl` || ParameterName==`require_secure_transport`)].ParameterValue' --output text)

    if [[ "$SSL_STATUS" == "0" || "$SSL_STATUS" == "OFF" || -z "$SSL_STATUS" ]]; then
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo "Parameter Group: $PARAM_GROUP"
      echo "SSL Enforcement: Disabled"
      echo "Status: Non-Compliant - SSL is not enforced"
      echo "--------------------------------------------------"
    fi
  done
done

echo ""

# Aurora Cluster Audit (only non-compliant clusters)
echo "Aurora Cluster Audit Results"
echo "--------------------------------------------------"

for REGION in "${!region_aurora_count[@]}"; do
  if [[ "${region_aurora_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  echo "Checking region: $REGION"

  for CLUSTER_ID in $(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" --query 'DBClusters[*].DBClusterIdentifier' --output text); do
    PARAM_GROUP=$(aws rds describe-db-clusters --region "$REGION" --profile "$PROFILE" --db-cluster-identifier "$CLUSTER_ID" --query 'DBClusters[*].DBClusterParameterGroup' --output text)

    if [[ -z "$PARAM_GROUP" ]]; then
      continue
    fi

    SSL_STATUS=$(aws rds describe-db-cluster-parameters --region "$REGION" --profile "$PROFILE" --db-cluster-parameter-group-name "$PARAM_GROUP" --query 'Parameters[?(ParameterName==`rds.force_ssl` || ParameterName==`require_secure_transport`)].ParameterValue' --output text)

    if [[ "$SSL_STATUS" == "0" || "$SSL_STATUS" == "OFF" || -z "$SSL_STATUS" ]]; then
      echo "Region: $REGION"
      echo "Cluster ID: $CLUSTER_ID"
      echo "Parameter Group: $PARAM_GROUP"
      echo "SSL Enforcement: Disabled"
      echo "Status: Non-Compliant - SSL is not enforced"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
