#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS MySQL/PostgreSQL IAM Database Authentication"
criteria="This script checks all Amazon RDS MySQL and PostgreSQL database instances in each AWS region to verify if IAM Database Authentication is enabled. Instances with IAM authentication disabled are considered non-compliant."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[?Engine==\`mysql\` || Engine==\`postgres\`].DBInstanceIdentifier | []'
  3. aws rds describe-db-instances --region \$REGION --db-instance-identifier \$INSTANCE_ID --query 'DBInstances[*].IAMDatabaseAuthenticationEnabled'"

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

for REGION in $regions; do
  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[?Engine==`mysql` || Engine==`postgres`].DBInstanceIdentifier' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count["$REGION"]=$instance_count

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+------------------+"
echo ""

# Perform detailed audit for non-compliant instances
non_compliant_found=false
echo "Starting compliance audit..."
for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[?Engine==`mysql` || Engine==`postgres`].DBInstanceIdentifier' --output text)

  for INSTANCE_ID in $instances; do
    # Fetch IAM authentication status
    IAM_AUTH=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
      --db-instance-identifier "$INSTANCE_ID" \
      --query "DBInstances[*].IAMDatabaseAuthenticationEnabled" --output text)

    # Check if IAM authentication is disabled
    if [[ "$IAM_AUTH" == "False" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo "IAM Database Authentication: Disabled"
      echo "Status: Non-Compliant - IAM Authentication is not enabled"
      echo "--------------------------------------------------"
      non_compliant_found=true
    fi
  done
done

# Display compliance message if no non-compliance found
if [ "$non_compliant_found" = false ]; then
  echo "No non-compliant RDS instances found."
fi

echo "Audit completed for all regions."
