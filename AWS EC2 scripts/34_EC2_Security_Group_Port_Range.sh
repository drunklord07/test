#!/bin/bash

# Description and Criteria
description="AWS Audit for Security Groups Using Port Ranges Instead of Specific Ports"
criteria="This script checks if security groups allow inbound traffic using port ranges instead of specific ports."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-security-groups --region \$REGION --query 'SecurityGroups[*].GroupId'
  3. aws ec2 describe-security-groups --region \$REGION --group-ids \$SG_ID --query 'SecurityGroups[*].IpPermissions'"

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
echo "Region         | Security Groups Found     "
echo "+----------------+--------------------------+"

# Dictionary to store non-compliant security groups
declare -A non_compliant_sgs

# Audit each region
for REGION in $regions; do
  # Get all security group IDs
  sg_ids=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
    --query 'SecurityGroups[*].GroupId' --output text)

  # Initialize counts
  sg_count=0
  non_compliant_count=0
  non_compliant_list=""

  # Count total security groups in the region
  for SG_ID in $sg_ids; do
    sg_count=$((sg_count + 1))

    # Get security group ingress rules
    ingress_rules=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
      --group-ids "$SG_ID" --query 'SecurityGroups[*].IpPermissions' --output json)

    # Check if security group uses port ranges
    while IFS= read -r line; do
      FROM_PORT=$(echo "$line" | jq -r '.FromPort')
      TO_PORT=$(echo "$line" | jq -r '.ToPort')

      if [[ "$FROM_PORT" != "null" && "$TO_PORT" != "null" && "$FROM_PORT" -ne "$TO_PORT" ]]; then
        non_compliant_count=$((non_compliant_count + 1))
        non_compliant_list+="$SG_ID (Port Range: $FROM_PORT-$TO_PORT)\n"
        break
      fi
    done < <(echo "$ingress_rules" | jq -c '.[] | .[]')

  done

  # Output result per region
  printf "| %-14s | ${PURPLE}%-25s${NC} |\n" "$REGION" "$sg_count SG(s) found"

  # Store non-compliant security groups for audit section
  if [ "$non_compliant_count" -gt 0 ]; then
    non_compliant_sgs["$REGION"]="$non_compliant_list"
  fi
done

echo "+----------------+--------------------------+"
echo ""

# Audit Section
if [ ${#non_compliant_sgs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant Security Groups:${NC}"
  echo "---------------------------------------------------"

  for region in "${!non_compliant_sgs[@]}"; do
    echo -e "${PURPLE}Region: $region${NC}"
    echo "Security Group IDs with Port Ranges:"
    echo -e "${non_compliant_sgs[$region]}" | awk '{print " - " $0}'
    echo "---------------------------------------------------"
  done
else
  echo -e "${GREEN}No non-compliant security groups detected.${NC}"
fi

echo "Audit completed for all regions."
