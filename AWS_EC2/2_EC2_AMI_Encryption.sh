#!/bin/bash

# Description and Criteria
description="AWS AMI Encryption Audit"
criteria="This script lists all AMIs owned by the account and checks if their snapshots are encrypted.
If an AMI is unencrypted, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# AWS CLI Commands Used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId'
  3. aws ec2 describe-images --region \$REGION --image-ids \$IMAGE_IDS --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted[]'"

# Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display Description and Commands
echo ""
echo "---------------------------------------------------------------------"
echo -e "${PURPLE}Description: $description${NC}"
echo ""
echo -e "${PURPLE}Criteria: $criteria${NC}"
echo ""
echo -e "${PURPLE}$command_used${NC}"
echo "---------------------------------------------------------------------"
echo ""

# Set AWS CLI Profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get AWS Regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+-----------------+"
echo "| Region        | Total AMIs       |"
echo "+----------------+-----------------+"

declare -A region_ami_count
for REGION in $regions; do
  ami_count=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'length(Images)' --output text)
  
  if [ "$ami_count" == "None" ]; then
    ami_count=0
  fi

  region_ami_count[$REGION]=$ami_count
  printf "| %-14s | %-15s |\n" "$REGION" "$ami_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit Section
for REGION in "${!region_ami_count[@]}"; do
  if [ "${region_ami_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    # Get all AMI IDs
    images=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'Images[*].ImageId' --output text)

    total_amis=0
    compliant_amis=0
    non_compliant_amis=0

    # Function to process AMIs in batches of 50
    process_amis() {
      local image_ids="$1"
      encrypted_status=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --image-ids $image_ids --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted' --output text | tr '\n' ' ')

      total_batch=$(echo "$image_ids" | wc -w)
      total_amis=$((total_amis + total_batch))

      if [[ "$encrypted_status" == *"False"* ]]; then
        non_compliant_batch=$(echo "$encrypted_status" | grep -o "False" | wc -l)
        non_compliant_amis=$((non_compliant_amis + non_compliant_batch))
      fi

      compliant_batch=$((total_batch - non_compliant_batch))
      compliant_amis=$((compliant_amis + compliant_batch))
    }

    # Process AMIs in batches of 50 using parallel execution
    echo "$images" | xargs -n 50 -P 5 bash -c 'process_amis "$@"' _

    echo "--------------------------------------------------"
    echo "Total AMIs Checked: $total_amis"
    echo -e "Compliant (Encrypted): ${GREEN}$compliant_amis${NC}"
    echo -e "Non-Compliant (Not Encrypted): ${RED}$non_compliant_amis${NC}"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AMIs."
