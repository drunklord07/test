#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances with IAM Roles"
criteria="This script checks all EC2 instances in each AWS region to verify whether they have an associated IAM role (instance profile). Instances without an IAM role may have limited access to AWS resources or require manual credential management."

# Commands used in this script
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn'"

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
echo "+----------------+----------------+"
echo "| Region         | Instances Found |"
echo "+----------------+----------------+"

# Collect instance count per region
declare -A region_instance_count

for REGION in $regions; do
  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  instance_count=$(echo "$instance_ids" | wc -w)
  region_instance_count["$REGION"]=$instance_count

  printf "| %-14s | %-16s |\n" "$REGION" "$instance_count"
done

echo "+----------------+----------------+"
echo ""

# Perform detailed audit per instance
for REGION in "${!region_instance_count[@]}"; do
  if [[ "${region_instance_count[$REGION]}" -eq 0 ]]; then
    continue
  fi

  echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

  instance_ids=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  for INSTANCE_ID in $instance_ids; do
    # Fetch IAM instance profile ARN
    IAM_ROLE_ARN=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[*].Instances[*].IamInstanceProfile.Arn" --output text)

    # Determine status
    if [[ -z "$IAM_ROLE_ARN" || "$IAM_ROLE_ARN" == "None" ]]; then
      STATUS="${RED}❌ No IAM Role Assigned${NC}"
    else
      STATUS="${GREEN}✅ IAM Role Assigned: $IAM_ROLE_ARN${NC}"
    fi

    # Print instance audit result
    echo "--------------------------------------------------"
    echo "Region: $REGION"
    echo "Instance ID: $INSTANCE_ID"
    echo "IAM Role ARN: ${IAM_ROLE_ARN:-None}"
    echo -e "Status: $STATUS"
    echo "--------------------------------------------------"
  done
done

echo "Audit completed for all regions."
