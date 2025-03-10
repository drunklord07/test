#!/bin/bash

# Description and Criteria
description="AWS EBS Volume Encryption Key Audit"
criteria="This script lists all EBS volumes across multiple AWS regions and checks if they are encrypted with a customer-managed key (CMK) or an AWS-managed key.
If a volume is unencrypted, it is marked as 'Non-Compliant' (printed in red). If it is encrypted with an AWS-managed key, it is marked as 'AWS-Managed' (printed in yellow).
If it is encrypted with a customer-managed key (CMK), it is marked as 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-volumes --region \$REGION --query 'Volumes[*].VolumeId'
  3. aws ec2 describe-volumes --region \$REGION --volume-ids \$VOLUME_ID --query 'Volumes[*].KmsKeyId'
  4. aws kms describe-key --region \$REGION --key-id \$KMS_KEY_ARN --query 'KeyMetadata.KeyManager'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display description, criteria, and the command being used
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
echo "\n+----------------+-----------------+"
echo "| Region        | Total Volumes   |"
echo "+----------------+-----------------+"

# Loop through each region and count EBS volumes
declare -A region_vol_count
for REGION in $regions; do
  volume_count=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
    --query 'length(Volumes)' --output text)

  if [ "$volume_count" == "None" ]; then
    volume_count=0
  fi

  region_vol_count[$REGION]=$volume_count
  printf "| %-14s | %-15s |\n" "$REGION" "$volume_count"
done
echo "+----------------+-----------------+"
echo ""

# Example Output:
# ----------------------------------------------
# | Region        | Total Volumes   |
# ----------------------------------------------
# | us-east-1     | 5               |
# | us-west-2     | 3               |
# | ap-south-1    | 7               |
# ----------------------------------------------

# Audit only regions with EBS volumes
for REGION in "${!region_vol_count[@]}"; do
  if [ "${region_vol_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    volumes=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
      --query 'Volumes[*].VolumeId' --output text)

    while read -r volume_id; do
      kms_key_arn=$(aws ec2 describe-volumes --region "$REGION" --profile "$PROFILE" \
        --volume-ids "$volume_id" --query 'Volumes[*].KmsKeyId' --output text)

      echo "--------------------------------------------------"
      echo "Volume ID: $volume_id"

      if [ -z "$kms_key_arn" ] || [ "$kms_key_arn" == "None" ]; then
        echo -e "Status: ${RED} Non-Compliant (Not Encrypted)${NC}"
      else
        key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" \
          --key-id "$kms_key_arn" --query 'KeyMetadata.KeyManager' --output text)

        if [ "$key_manager" == "AWS" ]; then
          echo -e "Status: ${YELLOW} AWS-Managed Key (Not CMK)${NC}"
        else
          echo -e "Status: ${GREEN} Compliant (Customer-Managed Key)${NC}"
        fi

        echo "KMS Key ARN: $kms_key_arn"
        echo "Key Manager: $key_manager"
      fi
    done <<< "$volumes"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AWS EBS volumes."
