#!/bin/bash

# Description and Criteria
description="AWS Audit for EBS Volume Encryption with Customer-Managed KMS Keys"
criteria="This script verifies if encrypted Amazon EBS volumes use customer-managed KMS keys instead of AWS-managed keys."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-volumes --region \$REGION --filters Name=encrypted,Values=true --query 'Volumes[*].VolumeId'
  2. aws ec2 describe-volumes --region \$REGION --volume-ids \$VOLUME_ID --query 'Volumes[*].KmsKeyId'
  3. aws kms describe-key --region \$REGION --key-id \$KMS_ARN --query 'KeyMetadata.KeyManager'"

# Color codes
GREEN='\033[0;32m'
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
echo "Region         | Total EBS Volumes Checked"
echo "+--------------+------------------------+"

declare -A region_compliance

# Audit each region
for REGION in $regions; do
  volume_ids=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" --filters Name=encrypted,Values=true --query 'Volumes[*].VolumeId' --output text)

  checked_count=0
  non_compliant_volumes=()

  for VOLUME_ID in $volume_ids; do
    checked_count=$((checked_count + 1))

    # Get KMS Key ARN
    kms_arn=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" --volume-ids "$VOLUME_ID" --query 'Volumes[*].KmsKeyId' --output text 2>/dev/null)

    if [[ -z "$kms_arn" ]]; then
      continue
    fi

    # Get Key Manager
    key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_arn" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

    if [[ "$key_manager" == "AWS" ]]; then
      non_compliant_volumes+=("$VOLUME_ID")
    fi
  done

  region_compliance["$REGION"]="${non_compliant_volumes[@]}"

  printf "| %-14s | %-24s |\n" "$REGION" "$checked_count"
done

echo "+--------------+------------------------+"
echo ""

# Audit Section
non_compliant_found=false

for region in "${!region_compliance[@]}"; do
  if [[ -n "${region_compliance[$region]}" ]]; then
    non_compliant_found=true
    break
  fi
done

if $non_compliant_found; then
  echo -e "${PURPLE}Non-Compliant AWS Regions:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!region_compliance[@]}"; do
    if [[ -n "${region_compliance[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant EBS Volumes:"
      for volume in ${region_compliance[$region]}; do
        echo " - $volume"
      done
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All AWS regions have compliant EBS volumes.${NC}"
fi

echo "Audit completed for all regions."
