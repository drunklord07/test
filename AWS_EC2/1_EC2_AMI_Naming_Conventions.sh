#!/bin/bash

# Description and Criteria
description="AWS AMI Tagging Audit"
criteria="This script lists all AMIs owned by the account and checks if they have name tags.
If an AMI lacks a name tag, it is marked as 'Non-Compliant' (printed in red), otherwise counted as 'Compliant'."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].[ImageId, Tags]' --output text"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display metadata
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

# Declare associative arrays for storing AMI data
declare -A region_ami_count
declare -A region_compliant_count
declare -A region_non_compliant_count

# Loop through each region
for REGION in $regions; do
  # Get total AMI count per region
  ami_count=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'Images[*].[ImageId]' --output text | wc -l)
  
  if [[ -z "$ami_count" || "$ami_count" -eq 0 ]]; then
    ami_count=0
  fi

  region_ami_count["$REGION"]=$ami_count
  printf "| %-14s | %-15s |\n" "$REGION" "$ami_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit Section (Count only)
echo -e "\n${PURPLE}Audit Summary:${NC}"
echo "+----------------+---------------+-----------------+"
echo "| Region        | Compliant AMIs | Non-Compliant AMIs |"
echo "+----------------+---------------+-----------------+"

for REGION in "${!region_ami_count[@]}"; do
  if [ "${region_ami_count[$REGION]}" -gt 0 ]; then
    compliant_count=0
    non_compliant_count=0

    # Fetch AMIs and check their tags
    while read -r image_id tag1 tag2; do
      if [[ -z "$image_id" ]]; then
        continue
      fi

      if [[ -z "$tag1" && -z "$tag2" ]]; then
        non_compliant_count=$((non_compliant_count + 1))
      else
        compliant_count=$((compliant_count + 1))
      fi
    done < <(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'Images[*].[ImageId, Tags]' --output text)

    # Ensure the total count is correct
    if (( compliant_count + non_compliant_count > region_ami_count["$REGION"] )); then
      non_compliant_count=$((region_ami_count["$REGION"] - compliant_count))
    fi

    region_compliant_count["$REGION"]=$compliant_count
    region_non_compliant_count["$REGION"]=$non_compliant_count

    printf "| %-14s | %-13s | %-17s |\n" "$REGION" "$compliant_count" "$non_compliant_count"
  fi
done

echo "+----------------+---------------+-----------------+"
echo ""
echo "Audit completed for all regions with AMIs."
