#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Group Naming Conventions"
criteria="This script checks if EC2 Security Groups follow the defined naming convention in each AWS region."

# Command used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --query 'SecurityGroups[*].GroupId'
  3. aws ec2 describe-security-groups --region \$REGION --group-ids \$SG_ID --query 'SecurityGroups[*].Tags'"

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

# Define naming convention regex pattern
NAMING_PATTERN="^security-group-(ue1|uw1|uw2|ew1|ec1|an1|an2|as1|as2|se1)-(d|t|s|p)-([a-z0-9\-]+)$"

# Table Header
echo "\nRegion         | Non-Compliant Security Groups   "
echo "+----------------+--------------------------------+"

# Dictionary to store non-compliant security groups
declare -A non_compliant_sgs

# Audit each region
for REGION in $regions; do
  # Get all security group IDs
  sg_ids=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --query 'SecurityGroups[*].GroupId' --output text)

  # Initialize non-compliant count
  non_compliant_count=0
  non_compliant_list=""

  for SG_ID in $sg_ids; do
    # Get security group name tag
    sg_name=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --group-ids "$SG_ID" --query 'SecurityGroups[*].Tags[?Key==`Name`].Value' --output text)

    # Check if name follows pattern
    if [[ ! "$sg_name" =~ $NAMING_PATTERN ]]; then
      non_compliant_count=$((non_compliant_count + 1))
      non_compliant_list+="$SG_ID ($sg_name)\n"
    fi
  done

  # Output result per region
  if [ "$non_compliant_count" -gt 0 ]; then
    printf "| %-14s | ${RED}%-30s${NC} |\n" "$REGION" "$non_compliant_count SG(s) found"
    non_compliant_sgs["$REGION"]="$non_compliant_list"
  else
    printf "| %-14s | ${GREEN}None detected${NC}                   |\n" "$REGION"
  fi
done

echo "+----------------+--------------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_sgs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Security Groups:${NC}"
  echo "---------------------------------------------------"

  for region in "${!non_compliant_sgs[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Security Group IDs (Name Tag):"
    echo -e "${non_compliant_sgs[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No non-compliant security groups detected.${NC}"
fi

echo "Audit completed for all regions."
