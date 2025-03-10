#!/bin/bash

# Description and Criteria
description="AWS Audit for VPC Naming Conventions"
criteria="This script checks if VPCs follow a naming convention as per AWS best practices."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-vpcs --region \$REGION --query 'Vpcs[*].VpcId'
  3. aws ec2 describe-vpcs --region \$REGION --vpc-ids \$VPC_ID --query 'Vpcs[*].Tags'"

# Define the regex pattern (modify as needed)
naming_pattern="^vpc-(ue1|uw1|uw2|ew1|ec1|an1|an2|as1|as2|se1)-(d|t|s|p)-([a-z0-9\-]+)$"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
echo "\n+----------------+----------------+"
echo "| Region         | VPC Count      |"
echo "+----------------+----------------+"

# Dictionary for storing VPC counts
declare -A vpc_counts

# Audit each region
for REGION in $regions; do
  # Count VPCs
  vpcs=$(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" \
    --query 'Vpcs[*].VpcId' --output text)
  vpc_count=$(echo "$vpcs" | wc -w)
  vpc_counts[$REGION]=$vpc_count

  printf "| %-14s | %-14s |\n" "$REGION" "$vpc_count"
done
echo "+----------------+----------------+"
echo ""

# Audit each VPC for Naming Convention
for REGION in "${!vpc_counts[@]}"; do
  if [ "${vpc_counts[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    for VPC_ID in $(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" \
      --query 'Vpcs[*].VpcId' --output text); do

      # Get VPC Name tag
      vpc_name=$(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" \
        --vpc-ids "$VPC_ID" --query 'Vpcs[*].Tags[?Key==`Name`].Value' --output text)

      if [[ -z "$vpc_name" ]]; then
        STATUS="${RED}Non-Compliant (No Name Tag)${NC}"
      elif [[ ! "$vpc_name" =~ $naming_pattern ]]; then
        STATUS="${RED}Non-Compliant (Invalid Naming Pattern)${NC}"
      else
        STATUS="${GREEN}Compliant${NC}"
      fi

      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "VPC ID: $VPC_ID"
      echo "VPC Name: $vpc_name"
      echo "Status: $STATUS"
      echo "--------------------------------------------------"
    done
  fi
done

echo "Audit completed for all regions."
