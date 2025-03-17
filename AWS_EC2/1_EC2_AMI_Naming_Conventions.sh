#!/bin/bash

# Description and Criteria
description="AWS AMI Tagging Audit"
criteria="This script lists all AMIs owned by the account and verifies if they have a 'Name' tag.
If an AMI lacks a 'Name' tag, it is marked as 'Non-Compliant' (printed in red). If the 'Name' tag exists, it must follow AWS best practices."

# Command being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --output table --query 'Images[*].Tags'"

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

declare -A region_ami_count
for REGION in $regions; do
  ami_count=$(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'Images[*].ImageId' --output text | wc -l)
  ami_count=${ami_count:-0} # Default to 0 if no AMIs

  region_ami_count[$REGION]=$ami_count
  printf "| %-14s | %-15s |\n" "$REGION" "$ami_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit Section
echo -e "\n${PURPLE}Audit Summary:${NC}"
echo "+----------------+---------------+-----------------+"
echo "| Region        | Compliant AMIs | Non-Compliant AMIs |"
echo "+----------------+---------------+-----------------+"

for REGION in "${!region_ami_count[@]}"; do
  ami_total=${region_ami_count[$REGION]}
  if [ "$ami_total" -gt 0 ]; then
    compliant_count=0
    non_compliant_count=0

    while IFS=$'\t' read -r image_id name_tag; do
      if [[ -z "$image_id" ]]; then
        continue
      fi

      if [[ -z "$name_tag" || "$name_tag" == "None" ]]; then
        non_compliant_count=$((non_compliant_count + 1))
      else
        # Validate Name tag against AWS best practice pattern
        if [[ "$name_tag" =~ ^ami-(ue1|uw1|uw2|ew1|ec1|an1|an2|as1|as2|se1)-(d|t|s|p)-[a-z0-9\-]+$ ]]; then
          compliant_count=$((compliant_count + 1))
        else
          non_compliant_count=$((non_compliant_count + 1))
        fi
      fi
    done < <(aws ec2 describe-images --region "$REGION" --profile "$PROFILE" --owners self --query 'Images[*].[ImageId, Tags[?Key==`Name`].Value | [0]]' --output text)

    # Ensure we never exceed the total count
    if (( compliant_count + non_compliant_count > ami_total )); then
      non_compliant_count=$((ami_total - compliant_count))
    fi

    printf "| %-14s | %-13s | %-17s |\n" "$REGION" "$compliant_count" "$non_compliant_count"
  fi
done

echo "+----------------+---------------+-----------------+"
echo ""
echo "Audit completed for all regions with AMIs."
