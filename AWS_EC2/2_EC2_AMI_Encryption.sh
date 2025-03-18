#!/bin/bash

# Description and Criteria
description="AWS AMI Encryption Audit"
criteria="This script lists all AMIs owned by the account and checks if their snapshots are encrypted.
If an AMI is unencrypted, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId'
  3. aws ec2 describe-images --region \$REGION --image-ids \$IMAGE_ID --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted[]'"

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
echo "\n+----------------+-----------------+"
echo "| Region        | Total AMIs       |"
echo "+----------------+-----------------+"

declare -A region_ami_count

# Fetch AMI count for each region
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

# Function to process AMIs in batches
process_amis() {
  local REGION="$1"
  shift
  local IMAGE_IDS=("$@")

  local compliant_count=0
  local non_compliant_count=0

  for IMAGE_ID in "${IMAGE_IDS[@]}"; do
    encrypted=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
      --image-ids "$IMAGE_ID" --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted' --output text)

    if [[ "$encrypted" == *"False"* ]]; then
      ((non_compliant_count++))
    else
      ((compliant_count++))
    fi
  done

  echo "$REGION $compliant_count $non_compliant_count"
}

# Audit AMIs in each region
for REGION in "${!region_ami_count[@]}"; do
  if [ "${region_ami_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    # Get all AMI IDs for the region
    mapfile -t image_ids < <(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'Images[*].ImageId' --output text)

    # Initialize compliance counts
    total_compliant=0
    total_non_compliant=0

    # Process AMIs in batches of 50
    batch_size=50
    num_images=${#image_ids[@]}

    for ((i = 0; i < num_images; i += batch_size)); do
      batch=("${image_ids[@]:i:batch_size}")
      result=$(process_amis "$REGION" "${batch[@]}")

      region_name=$(echo "$result" | awk '{print $1}')
      compliant=$(echo "$result" | awk '{print $2}')
      non_compliant=$(echo "$result" | awk '{print $3}')

      ((total_compliant += compliant))
      ((total_non_compliant += non_compliant))
    done

    # Display summary
    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo -e "Compliant AMIs: ${GREEN}$total_compliant${NC}"
    echo -e "Non-Compliant AMIs: ${RED}$total_non_compliant${NC}"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AMIs."
