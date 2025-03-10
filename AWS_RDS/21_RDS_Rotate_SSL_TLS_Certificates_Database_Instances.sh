#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS CA Certificate Expiry"
criteria="This script verifies whether Amazon RDS instances are using CA certificates that are expired or nearing expiration."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceIdentifier'
  3. aws rds describe-db-instances --region \$REGION --db-instance-identifier \$DB_INSTANCE --query 'DBInstances[*].CACertificateIdentifier'
  4. aws rds describe-certificates --region \$REGION --certificate-identifier \$CA_CERT --query 'Certificates[*].ValidTill'"

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
echo "+----------------+----------------------+"
echo "| Region         | RDS Instances        |"
echo "+----------------+----------------------+"

# Collect database count per region
declare -A region_db_count
total_db_instances=0

for REGION in $regions; do
  db_instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceIdentifier' --output text)

  db_count=$(echo "$db_instances" | wc -w)
  region_db_count["$REGION"]=$db_count
  total_db_instances=$((total_db_instances + db_count))

  printf "| %-14s | %-20s |\n" "$REGION" "$db_count"
done

echo "+----------------+----------------------+"
echo ""

# Perform CA certificate expiry audit
non_compliant_found=false
if [[ "$total_db_instances" -eq 0 ]]; then
  echo "No RDS database instances found across all regions."
  exit 0
fi

echo "Starting CA certificate expiry audit..."
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

for REGION in "${!region_db_count[@]}"; do
  if [[ "${region_db_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  db_instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceIdentifier' --output text)

  for DB_INSTANCE in $db_instances; do
    ca_cert=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
      --db-instance-identifier "$DB_INSTANCE" --query 'DBInstances[*].CACertificateIdentifier' --output text)

    valid_till=$(aws rds describe-certificates --region "$REGION" --profile "$PROFILE" \
      --certificate-identifier "$ca_cert" --query 'Certificates[*].ValidTill' --output text)

    if [[ "$valid_till" < "$current_date" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "RDS Instance: $DB_INSTANCE"
      echo "CA Certificate: $ca_cert"
      echo "Valid Till: $valid_till"
      echo "Status: NON-COMPLIANT (Certificate Expired)"
      echo "Action: Rotate the CA certificate to a valid one."
      echo "--------------------------------------------------"
      non_compliant_found=true
    fi
  done
done

# Display compliance message only if all certificates are valid
if [ "$non_compliant_found" = false ]; then
  echo "All RDS instances have valid CA certificates."
fi

echo "Audit completed for all regions."
