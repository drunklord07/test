#!/bin/bash

# Description and Criteria
description="AWS Audit for AWS Backup Vault Encryption Compliance"
criteria="This script checks if AWS Backup vaults use Customer Managed Keys (CMK) for encryption instead of AWS-managed default keys."

# Commands used
command_used="Commands Used:
  1. aws backup list-backup-vaults --region \$REGION --query 'BackupVaultList[?(BackupVaultName!=\`Default\`)].BackupVaultName' --output text
  2. aws backup describe-backup-vault --region \$REGION --backup-vault-name \$VAULT_NAME --query 'EncryptionKeyArn' --output text
  3. aws kms describe-key --region \$REGION --key-id \$KMS_KEY_ARN --query 'KeyMetadata.KeyManager' --output text"

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
echo "Region         | Total Backup Vaults"
echo "+--------------+-------------------+"

declare -A total_vaults
declare -A non_compliant_vaults

# Audit each region
for REGION in $regions; do
  vaults=$(aws backup list-backup-vaults --region "$REGION" --profile "$PROFILE" --query 'BackupVaultList[?(BackupVaultName!=`Default`)].BackupVaultName' --output text 2>/dev/null)

  vault_count=0
  non_compliant_list=()

  for VAULT_NAME in $vaults; do
    ((vault_count++))

    kms_key_arn=$(aws backup describe-backup-vault --region "$REGION" --profile "$PROFILE" --backup-vault-name "$VAULT_NAME" --query 'EncryptionKeyArn' --output text 2>/dev/null)

    if [[ -z "$kms_key_arn" || "$kms_key_arn" == "None" ]]; then
      non_compliant_list+=("$VAULT_NAME (No Encryption Key Configured)")
      continue
    fi

    key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_key_arn" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

    if [[ "$key_manager" == "AWS" ]]; then
      non_compliant_list+=("$VAULT_NAME (Uses AWS Managed Key)")
    fi
  done

  total_vaults["$REGION"]=$vault_count
  non_compliant_vaults["$REGION"]="${non_compliant_list[@]}"

  printf "| %-14s | %-19s |\n" "$REGION" "$vault_count"
done

echo "+--------------+-------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_vaults[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant AWS Backup Vaults:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_vaults[@]}"; do
    if [[ -n "${non_compliant_vaults[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant Backup Vaults:"
      for vault in ${non_compliant_vaults[$region]}; do
        echo " - $vault"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS Backup vaults use Customer Managed Keys (CMK) for encryption.${NC}"
fi

echo "Audit completed for all regions."
