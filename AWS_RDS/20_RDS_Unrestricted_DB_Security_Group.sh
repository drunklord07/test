#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS DB Security Groups with Unrestricted Access"
criteria="This script verifies whether Amazon RDS DB security groups allow unrestricted access by checking if any security group contains CIDRIP '0.0.0.0/0' with status 'authorized'."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-security-groups --region \$REGION --query 'DBSecurityGroups[*].DBSecurityGroupName'
  3. aws rds describe-db-security-groups --region \$REGION --db-security-group-name \$SECURITY_GROUP"

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
echo "+----------------+---------------------+"
echo "| Region         | DB Security Groups  |"
echo "+----------------+---------------------+"

# Collect security group count per region
declare -A region_security_group_count
total_security_groups=0

for REGION in $regions; do
  security_groups=$(aws rds describe-db-security-groups --region "$REGION" --profile "$PROFILE" \
    --query 'DBSecurityGroups[*].DBSecurityGroupName' --output text)

  security_group_count=$(echo "$security_groups" | wc -w)
  region_security_group_count["$REGION"]=$security_group_count
  total_security_groups=$((total_security_groups + security_group_count))

  printf "| %-14s | %-19s |\n" "$REGION" "$security_group_count"
done

echo "+----------------+---------------------+"
echo ""

# Perform security audit
non_compliant_found=false
if [[ "$total_security_groups" -eq 0 ]]; then
  echo "No RDS DB security groups found across all regions."
  exit 0
fi

echo "Starting compliance audit..."
for REGION in "${!region_security_group_count[@]}"; do
  if [[ "${region_security_group_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  security_groups=$(aws rds describe-db-security-groups --region "$REGION" --profile "$PROFILE" \
    --query 'DBSecurityGroups[*].DBSecurityGroupName' --output text)

  for SECURITY_GROUP in $security_groups; do
    security_group_details=$(aws rds describe-db-security-groups --region "$REGION" --profile "$PROFILE" \
      --db-security-group-name "$SECURITY_GROUP" --query 'DBSecurityGroups[*].IPRanges[*]' --output json)

    if echo "$security_group_details" | grep -q '"CIDRIP": "0.0.0.0/0"'; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "DB Security Group: $SECURITY_GROUP"
      echo "Status: NON-COMPLIANT (Allows 0.0.0.0/0)"
      echo "Action: Restrict access to authorized IP ranges only."
      echo "--------------------------------------------------"
      non_compliant_found=true
    fi
  done
done

# Display compliance message only if all security groups are compliant
if [ "$non_compliant_found" = false ]; then
  echo "All RDS DB security groups in all regions have restricted access."
fi

echo "Audit completed for all regions."
