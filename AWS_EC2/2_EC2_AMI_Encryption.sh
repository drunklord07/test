#!/bin/bash

# Description and Criteria
description="AWS AMI Encryption Audit"
criteria="This script lists all AMIs owned by the account and checks if their snapshots are encrypted.
If an AMI is unencrypted, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Commands used
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

# Loop through each region and count AMIs
declare -A region_ami_count
for REGION in $regions; do
  ami_count=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self \
    --query 'length(Images)' --output text)

  if [ "$ami_count" == "None" ]; then
    ami_count=0
  fi

  region_ami_count[$REGION]=$ami_count
  printf "| %-14s | %-15s |\n" "$REGION" "$ami_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with AMIs
for REGION in "${!region_ami_count[@]}"; do
  if [ "${region_ami_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    # Get list of all AMI IDs in the region
    images=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self \
      --query 'Images[*].ImageId' --output text)

    # Initialize counters
    compliant_count=0
    non_compliant_count=0

    # Process in batches of 50
    batch_size=50
    batch=()

    for image_id in $images; do
      batch+=("$image_id")

      # If batch size is reached or it's the last batch, process them
      if [[ "${#batch[@]}" -eq "$batch_size" || "$image_id" == "$(echo "$images" | tail -n 1)" ]]; then
        # Describe images in batch
        result=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --image-ids "${batch[@]}" \
          --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted' --output text)

        for encrypted in $result; do
          if [[ "$encrypted" == "True" ]]; then
            ((compliant_count++))
          else
            ((non_compliant_count++))
          fi
        done

        # Clear batch
        batch=()
      fi
    done

    # Display results
    echo "--------------------------------------------------"
    echo "Total AMIs in $REGION: ${region_ami_count[$REGION]}"
    echo -e "Compliant (Encrypted): ${GREEN}$compliant_count${NC}"
    echo -e "Non-Compliant (Not Encrypted): ${RED}$non_compliant_count${NC}"
    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with AMIs."
