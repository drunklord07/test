#!/bin/bash

# Description and Criteria
description="AWS Audit for Neptune database instances to check Storage Encryption and KMS Key Management."
criteria="Identifies Neptune database instances where encryption is disabled or where AWS-managed KMS keys are used instead of Customer-Managed Keys (CMK)."

# Commands used
command_used="Commands Used:
  aws neptune describe-db-instances --region \$REGION --query 'DBInstances[*].DBInstanceIdentifier'
  aws neptune describe-db-instances --region \$REGION --db-instance-identifier <instance_id> --query 'DBInstances[*].StorageEncrypted'
  aws neptune describe-db-instances --region \$REGION --db-instance-identifier <instance_id> --query 'DBInstances[*].KmsKeyId'
  aws kms describe-key --region \$REGION --key-id <kms_key_arn> --query 'KeyMetadata.KeyManager'"

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
echo "Region         | Total Neptune Instances | Non-Compliant Instances"
echo "+--------------+------------------------+-------------------------+"

declare -A non_compliant_instances

# Step 1: Fetch Neptune Instances Per Region
for REGION in $regions; do
    instance_ids=$(aws neptune describe-db-instances --region "$REGION" --profile "$PROFILE" --query 'DBInstances[*].DBInstanceIdentifier' --output text 2>/dev/null)

    if [[ -z "$instance_ids" ]]; then
        continue
    fi

    total_instances=0
    non_compliant_count=0
    non_compliant_details=""

    for INSTANCE_ID in $instance_ids; do
        ((total_instances++))

        # Check encryption status
        encryption_status=$(aws neptune describe-db-instances --region "$REGION" --profile "$PROFILE" --db-instance-identifier "$INSTANCE_ID" --query 'DBInstances[*].StorageEncrypted' --output text 2>/dev/null)
        
        [[ "$encryption_status" == "None" ]] && encryption_status="false"

        if [[ "$encryption_status" == "False" ]]; then
            ((non_compliant_count++))
            non_compliant_details+="Region: $REGION | Instance ID: $INSTANCE_ID | Storage Encryption: $encryption_status"$'\n'
            continue
        fi

        # Check KMS key
        kms_key_arn=$(aws neptune describe-db-instances --region "$REGION" --profile "$PROFILE" --db-instance-identifier "$INSTANCE_ID" --query 'DBInstances[*].KmsKeyId' --output text 2>/dev/null)
        
        if [[ -n "$kms_key_arn" && "$kms_key_arn" != "None" ]]; then
            key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_key_arn" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

            if [[ "$key_manager" == "AWS" ]]; then
                ((non_compliant_count++))
                non_compliant_details+="Region: $REGION | Instance ID: $INSTANCE_ID | KMS Key Manager: AWS (Not CMK)"$'\n'
            fi
        fi
    done

    if [[ $non_compliant_count -gt 0 ]]; then
        non_compliant_instances["$REGION"]="$non_compliant_details"
    fi

    printf "| %-14s | %-22s | %-23s |\n" "$REGION" "$total_instances" "$non_compliant_count"
done

echo "+--------------+------------------------+-------------------------+"
echo ""

# Step 2: Audit for Non-Compliant Instances
echo "---------------------------------------------------------------------"
echo "Audit Results (Neptune instances where encryption is disabled or using AWS-managed keys)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_instances[@]} -eq 0 ]]; then
    echo "All Neptune database instances have encryption enabled and use Customer-Managed KMS Keys (CMK)."
else
    for REGION in "${!non_compliant_instances[@]}"; do
        echo "Region: $REGION"
        echo "${non_compliant_instances[$REGION]}"
        echo "---------------------------------------------------------------------"
    done
fi

echo "Audit completed for all regions."
