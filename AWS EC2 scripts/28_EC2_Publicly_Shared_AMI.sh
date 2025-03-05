#!/bin/bash

# Description and Criteria
description="AWS Audit for Publicly Shared Amazon Machine Images (AMIs)"
criteria="This script identifies AMIs that are publicly accessible.
AMIs with 'Public' set to 'true' are marked as 'Non-Compliant'."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId'
  3. aws ec2 describe-images --region \$REGION --image-ids \$AMI_ID --owners self --query 'Images[*].Public'"

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
echo "\n+----------------+----------------+----------------+"
echo "| Region         | Total AMIs      | Public AMIs    |"
echo "+----------------+----------------+----------------+"

# Audit each region
declare -A region_total_amis
declare -A region_public_amis

for REGION in $regions; do
  # Get all AMIs owned by the user
  ami_list=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
    --owners self --query 'Images[*].ImageId' --output text)

  total_ami_count=$(echo "$ami_list" | wc -w)
  public_ami_count=0

  # Check if each AMI is public
  for AMI_ID in $ami_list; do
    is_public=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
      --image-ids "$AMI_ID" --owners self --query 'Images[*].Public' --output text)

    if [ "$is_public" == "True" ]; then
      ((public_ami_count++))
    fi
  done

  region_total_amis[$REGION]=$total_ami_count
  region_public_amis[$REGION]=$public_ami_count

  printf "| %-14s | %-14s | %-14s |\n" "$REGION" "$total_ami_count" "$public_ami_count"
done
echo "+----------------+----------------+----------------+"
echo ""

# Show detailed audit results for each region
for REGION in "${!region_total_amis[@]}"; do
  if [ "${region_total_amis[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    ami_list=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
      --owners self --query 'Images[*].ImageId' --output text)

    for AMI_ID in $ami_list; do
      is_public=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
        --image-ids "$AMI_ID" --owners self --query 'Images[*].Public' --output text)

      if [ "$is_public" == "True" ]; then
        STATUS="${RED}Non-Compliant (Publicly Shared)${NC}"
      else
        STATUS="${GREEN}Compliant (Private AMI)${NC}"
      fi

      # Print audit details
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "AMI ID: $AMI_ID"
      echo "Public: $is_public"
      echo "Status: $STATUS"
      echo "--------------------------------------------------"
    done
  fi
done

echo "Audit completed for all regions."
