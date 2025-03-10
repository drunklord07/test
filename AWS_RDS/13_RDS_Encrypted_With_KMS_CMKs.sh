#!/bin/bash

# Description and Criteria
description="AWS Audit for RDS Database Storage Encryption and Key Management"
criteria="This script verifies whether Amazon RDS database instances are encrypted at rest and checks if they are using a customer-managed KMS key."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws rds describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceIdentifier'
  3. aws rds describe-db-instances --region \$REGION --db-instance-identifier \$INSTANCE --query 'DBInstances[*].{\"StorageEncrypted\":StorageEncrypted,\"KmsKeyId\":KmsKeyId}'
  4. aws kms describe-key --region \$REGION --key-id \$KMS_KEY --query 'KeyMetadata.KeyManager'"

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
    --query 'DBInstances[*].DBInstanceIdentifier' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count["$REGION"]=$instance_count

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+------------------+"
echo ""

# Perform detailed encryption audit
non_compliant_found=false
echo "Starting compliance audit..."
for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  instances=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
    --query 'DBInstances[*].DBInstanceIdentifier' --output text)

  for INSTANCE in $instances; do
    encryption_details=$(aws rds describe-db-instances --region "$REGION" --profile "$PROFILE" \
      --db-instance-identifier "$INSTANCE" \
      --query 'DBInstances[*].{"StorageEncrypted":StorageEncrypted,"KmsKeyId":KmsKeyId}' --output json)

    is_encrypted=$(echo "$encryption_details" | grep -o '"StorageEncrypted": [^,]*' | awk '{print $2}')
    kms_key_id=$(echo "$encryption_details" | grep -o '"KmsKeyId": "[^"]*' | cut -d'"' -f4)

    if [[ "$is_encrypted" == "false" ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance: $INSTANCE"
      echo "Encryption Status: Not Encrypted"
      echo "Action: Enable encryption for this RDS instance."
      echo "--------------------------------------------------"
      non_compliant_found=true
    else
      # Check KMS Key Management
      key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" \
        --key-id "$kms_key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

      if [[ "$key_manager" == "AWS" ]]; then
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Instance: $INSTANCE"
        echo "Encryption Status: Encrypted"
        echo "Key Manager: AWS Managed Key (Not a Customer CMK)"
        echo "Action: Consider using a Customer Managed Key (CMK) for enhanced security."
        echo "--------------------------------------------------"
        non_compliant_found=true
      else
        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Instance: $INSTANCE"
        echo "Encryption Status: Encrypted"
        echo "Key Manager: Customer Managed Key (CMK) in Use"
        echo "Status: Compliant"
        echo "--------------------------------------------------"
      fi
    fi
  done
done

# Display compliance message if no non-compliance found
if [ "$non_compliant_found" = false ]; then
  echo "All RDS instances in all regions are encrypted and compliant."
fi

echo "Audit completed for all regions."
