#!/bin/bash

# Description and Criteria
description="AWS Publicly Shared AMIs Audit"
criteria="This script lists all AMIs owned by the account in each AWS region and checks if any are publicly shared.
If an AMI is publicly shared, it is marked as 'Non-Compliant' (printed in red).
If all AMIs are private, a message is displayed."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-images --region \$REGION --owners self --query 'Images[*].ImageId'
  3. aws ec2 describe-images --region \$REGION --image-ids \$AMI_ID --query 'Images[*].Public'"

# Color codes
RED='\033[0;31m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
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
echo -e "\n+----------------+--------------+"
echo -e "| Region        | Total AMIs   |"
echo -e "+----------------+--------------+"

# Loop through each region and count AMIs
declare -A region_ami_count
for REGION in $regions; do
  ami_count=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
    --query 'length(Images[*])' --output text)

  if [ "$ami_count" == "None" ] || [ -z "$ami_count" ]; then
    ami_count=0
  fi

  region_ami_count[$REGION]=$ami_count
  printf "| %-14s | %-12s |\n" "$REGION" "$ami_count"
done
echo "+----------------+--------------+"
echo ""

# Track if any non-compliant AMIs were found
any_non_compliant=false
non_compliant_report=""

# Audit only regions with AMIs
for REGION in "${!region_ami_count[@]}"; do
  if [ "${region_ami_count[$REGION]}" -gt 0 ]; then

    # Fetch all AMI IDs
    amis=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
      --query 'Images[*].ImageId' --output text | tr ' ' '\n')

    if [ -z "$amis" ]; then
      continue
    fi

    region_non_compliant=""
    while read -r ami_id; do
      public_status=$(aws ec2 describe-images --region "$REGION" --owners self --profile "$PROFILE" \
        --image-ids "$ami_id" --query 'Images[*].Public' --output text)

      if [ "$public_status" == "True" ]; then
        any_non_compliant=true
        region_non_compliant+="$ami_id"$'\n'
      fi
    done <<< "$amis"

    if [ -n "$region_non_compliant" ]; then
      non_compliant_report+="\n${RED}Region: $REGION${NC}\n$region_non_compliant"
    fi
  fi
done

# Display audit results
if [ "$any_non_compliant" == "true" ]; then
  echo -e "\n--------------------------------------------------"
  echo -e "${RED}Non-Compliant AMIs (Publicly Shared)${NC}"
  echo -e "--------------------------------------------------"
  echo -e "$non_compliant_report"
  echo "--------------------------------------------------"
else
  echo -e "${GREEN}All AMIs across all regions are private.${NC}"
fi

echo "Audit completed for all regions with AMIs."
