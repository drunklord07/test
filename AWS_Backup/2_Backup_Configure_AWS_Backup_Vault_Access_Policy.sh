#!/bin/bash

# Description and Criteria
description="AWS Audit for AWS Backup Vault Access Policy Compliance"
criteria="This script checks if AWS Backup vaults have a valid access policy with deletion protection enabled."

# Commands used
command_used="Commands Used:
  1. aws backup list-backup-vaults --region \$REGION --query 'BackupVaultList[*].BackupVaultName' --output text
  2. aws backup get-backup-vault-access-policy --region \$REGION --backup-vault-name \$VAULT_NAME --query 'Policy' --output text"

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
  vaults=$(aws backup list-backup-vaults --region "$REGION" --profile "$PROFILE" --query 'BackupVaultList[*].BackupVaultName' --output text 2>/dev/null)

  vault_count=0
  non_compliant_list=()

  for VAULT_NAME in $vaults; do
    ((vault_count++))

    policy_output=$(aws backup get-backup-vault-access-policy --region "$REGION" --profile "$PROFILE" --backup-vault-name "$VAULT_NAME" --query 'Policy' --output text 2>&1)

    if echo "$policy_output" | grep -q "ResourceNotFoundException"; then
      non_compliant_list+=("$VAULT_NAME (No Access Policy)")
    elif ! echo "$policy_output" | grep -q '"Effect": "Deny"' || ! echo "$policy_output" | grep -q '"Action": "backup:DeleteRecoveryPoint"'; then
      non_compliant_list+=("$VAULT_NAME (No Deletion Protection)")
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
  echo -e "${GREEN}All AWS Backup vaults have valid deletion protection.${NC}"
fi

echo "Audit completed for all regions."
