#!/bin/bash

# Description and Criteria
description="AWS Default EBS Encryption Key Audit"
criteria="This script checks the default encryption key used for Amazon EBS volumes in multiple AWS regions.
If the default key is AWS-managed ('AWS'), it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 get-ebs-default-kms-key-id --region \$REGION --query 'KmsKeyId'
  3. aws kms describe-key --region \$REGION --key-id \$kms_key_arn --query 'KeyMetadata.KeyManager'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
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
echo "\n+----------------+-------------------------------+------------------+"
echo "| Region        | Default KMS Key ARN           | Compliance       |"
echo "+----------------+-------------------------------+------------------+"

# Loop through each region and check the default EBS encryption key
for REGION in $regions; do
  kms_key_arn=$(aws ec2 get-ebs-default-kms-key-id --region "$REGION" --profile "$PROFILE" --query 'KmsKeyId' --output text 2>/dev/null)

  # Check if no default key is set
  if [ "$kms_key_arn" == "None" ]; then
    kms_key_arn="No Default Key"
    compliance="${RED}Non-Compliant (Not Set)${NC}"
  else
    key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_key_arn" --query 'KeyMetadata.KeyManager' --output text)
    
    if [ "$key_manager" == "AWS" ]; then
      compliance="${RED}Non-Compliant (AWS-Managed)${NC}"
    else
      compliance="${GREEN}Compliant (Customer-Managed)${NC}"
    fi
  fi

  printf "| %-14s | %-29s | %-16s |\n" "$REGION" "$kms_key_arn" "$compliance"
done
echo "+----------------+-------------------------------+------------------+"
echo ""

echo "Audit completed for all AWS regions."
