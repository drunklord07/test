#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS Database Instances in Public Subnets"
criteria="This script verifies whether Amazon RDS instances are provisioned within public subnets by checking their associated route tables."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceIdentifier'
  3. aws rds describe-db-instances --region \$REGION --db-instance-identifier \$INSTANCE --query 'DBInstances[*].DBSubnetGroup.Subnets[*].SubnetIdentifier'
  4. aws ec2 describe-route-tables --region \$REGION --filters 'Name=association.subnet-id,Values=\$SUBNET' --query 'RouteTables[*].Routes[]'"

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

# Table Header
echo "+----------------+------------------+"
echo "| Region         | RDS Instances    |"
echo "+----------------+------------------+"

# Collect instance count per region
declare -A region_instance_count
total_instances=0

for REGION in $regions; do
  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceIdentifier' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count["$REGION"]=$instance_count
  total_instances=$((total_instances + instance_count))

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+------------------+"
echo ""

# Perform public subnet audit
non_compliant_found=false
if [[ "$total_instances" -eq 0 ]]; then
  echo "No RDS instances found across all regions."
  exit 0
fi

echo "Starting compliance audit..."
for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceIdentifier' --output text)

  for INSTANCE in $instances; do
    subnets=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
      --db-instance-identifier "$INSTANCE" \
      --query 'DBInstances[*].DBSubnetGroup.Subnets[*].SubnetIdentifier' --output text)

    for SUBNET in $subnets; do
      routes=$(aws ec2 describe-route-tables --region "$REGION" --profile "$PROFILE" \
        --filters "Name=association.subnet-id,Values=$SUBNET" \
        --query 'RouteTables[*].Routes[]' --output json)

      if echo "$routes" | grep -q '"GatewayId": "igw-'; then
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Instance: $INSTANCE"
        echo "Subnet: $SUBNET"
        echo "Status: Non-Compliant (Public Subnet Detected)"
        echo "Action: Move this RDS instance to a private subnet."
        echo "--------------------------------------------------"
        non_compliant_found=true
      fi

      if echo "$routes" | grep -q '"DestinationCidrBlock": "0.0.0.0/0"'; then
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Instance: $INSTANCE"
        echo "Subnet: $SUBNET"
        echo "Status: Non-Compliant (Route to 0.0.0.0/0 Detected)"
        echo "Action: Move this RDS instance to a private subnet."
        echo "--------------------------------------------------"
        non_compliant_found=true
      fi
    done
  done
done

# Display compliance message only if all instances are compliant
if [ "$non_compliant_found" = false ]; then
  echo "All RDS instances in all regions are running in private subnets and are compliant."
fi

echo "Audit completed for all regions."
