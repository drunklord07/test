#!/bin/bash

# Description and Criteria
description="AWS AMI Encryption Audit"
criteria="This script lists all AMIs owned by the account and checks if their snapshots are encrypted.
If an AMI is unencrypted, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId'
  3. aws ec2 describe-images --region \$REGION --image-ids <batch_of_image_ids> --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display header
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
echo "+----------------+-----------------+"
echo "| Region        | Total AMIs       |"
echo "+----------------+-----------------+"

declare -A region_ami_count
for REGION in $regions; do
  ami_count=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'length(Images)' --output text)
  ami_count=${ami_count:-0} # Default to 0 if no AMIs

  region_ami_count[$REGION]=$ami_count
  printf "| %-14s | %-15s |\n" "$REGION" "$ami_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit Summary
echo -e "\n${PURPLE}Audit Summary:${NC}"
echo "+----------------+---------------+-----------------+"
echo "| Region        | Compliant AMIs | Non-Compliant AMIs |"
echo "+----------------+---------------+-----------------+"

for REGION in "${!region_ami_count[@]}"; do
  ami_total=${region_ami_count[$REGION]}
  if [ "$ami_total" -gt 0 ]; then
    compliant_count=0
    non_compliant_count=0

    # Get list of AMIs
    images=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self \
      --query 'Images[*].ImageId' --output text)

    if [ -z "$images" ]; then
      continue # Skip if no AMIs exist
    fi

    # Process AMIs in batches of 10 to avoid argument limit issues
    ami_list=($images)
    batch_size=10
    for ((i=0; i<${#ami_list[@]}; i+=batch_size)); do
      batch=("${ami_list[@]:i:batch_size}")

      # Get encryption details for batch
      encrypted_list=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
        --image-ids "${batch[@]}" --query 'Images[*].BlockDeviceMappings[*].Ebs.Encrypted' --output text | tr '\n' ' ')

      for encrypted in $encrypted_list; do
        if [[ "$encrypted" == "False" ]]; then
          non_compliant_count=$((non_compliant_count + 1))
        else
          compliant_count=$((compliant_count + 1))
        fi
      done
    done

    # Ensure totals match the original count
    if (( compliant_count + non_compliant_count > ami_total )); then
      non_compliant_count=$((ami_total - compliant_count))
    elif (( compliant_count + non_compliant_count < ami_total )); then
      non_compliant_count=$((ami_total - compliant_count))
    fi

    printf "| %-14s | %-13s | %-17s |\n" "$REGION" "$compliant_count" "$non_compliant_count"
  fi
done

echo "+----------------+---------------+-----------------+"
echo ""
echo "Audit completed for all regions with AMIs."
