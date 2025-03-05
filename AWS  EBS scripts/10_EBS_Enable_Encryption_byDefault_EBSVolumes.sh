#!/bin/bash

# Description and Criteria
description="AWS EBS Encryption-by-Default Audit"
criteria="This script checks if EBS encryption by default is enabled across all AWS regions.
If encryption is disabled in any region, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 get-ebs-encryption-by-default --region \$REGION --query 'EbsEncryptionByDefault'"

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
echo "\n+----------------+--------------------+"
echo "| Region        | Encryption Status  |"
echo "+----------------+--------------------+"

# Loop through each region to check EBS encryption by default
for REGION in $regions; do
  encryption_status=$(aws ec2 get-ebs-encryption-by-default --region "$REGION" --profile "$PROFILE" \
    --query 'EbsEncryptionByDefault' --output text)

  echo "--------------------------------------------------"
  echo "Region: $REGION"
  if [ "$encryption_status" == "False" ]; then
    printf "| %-14s | ${RED}%-18s${NC} |\n" "$REGION" "Non-Compliant"
  else
    printf "| %-14s | ${GREEN}%-18s${NC} |\n" "$REGION" "Compliant"
  fi
done

echo "+----------------+--------------------+"
echo ""
echo "Audit completed for all AWS regions."
