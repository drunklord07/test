#!/bin/bash

# Description and Criteria
description="AWS Audit for Outdated Amazon Machine Images (AMI)"
criteria="This script identifies Amazon Machine Images (AMIs) older than 180 days. 
Outdated AMIs are marked as 'Non-Compliant' (printed in red)."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId'
  3. aws ec2 describe-images --region \$REGION --image-ids \$AMI_ID --query 'Images[*].CreationDate'"

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

# Get current date in UTC format
current_date=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
current_epoch=$(date -d "$current_date" +%s)
days_threshold=180
seconds_threshold=$((days_threshold * 86400)) # Convert days to seconds

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+---------------+"
echo "| Region         | AMIs Found    |"
echo "+----------------+---------------+"

# Audit each region for AMIs
for REGION in $regions; do
  ami_ids=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
    --query 'Images[*].ImageId' --output text)

  ami_count=$(echo "$ami_ids" | wc -w)

  printf "| %-14s | %-13s |\n" "$REGION" "$ami_count"
done
echo "+----------------+---------------+"
echo ""

# Check each AMI for creation date
for REGION in $regions; do
  ami_ids=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
    --query 'Images[*].ImageId' --output text)

  if [[ -z "$ami_ids" ]]; then
    continue
  fi

  echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

  for AMI_ID in $ami_ids; do
    creation_date=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" \
      --image-ids "$AMI_ID" \
      --query 'Images[*].CreationDate' --output text)

    if [[ -z "$creation_date" ]]; then
      continue
    fi

    # Convert creation date to epoch time
    creation_epoch=$(date -d "$creation_date" +%s)
    age_seconds=$((current_epoch - creation_epoch))
    age_days=$((age_seconds / 86400))

    if [[ $age_seconds -gt $seconds_threshold ]]; then
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "AMI ID: $AMI_ID"
      echo "Creation Date: $creation_date"
      echo -e "Status: ${RED} Non-Compliant (Older than 180 days)${NC}"
      echo "--------------------------------------------------"
    else
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "AMI ID: $AMI_ID"
      echo "Creation Date: $creation_date"
      echo -e "Status: ${GREEN} Compliant (Up-to-date)${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

echo "Audit completed for all regions."
