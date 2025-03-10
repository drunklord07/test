#!/bin/bash

# Description and Criteria
description="AWS EC2 Instance IAM Role Audit"
criteria="This script lists all EC2 instances in each AWS region and checks if they have an IAM instance profile assigned.
If an instance lacks an IAM role, it is marked as 'Non-Compliant' (printed in red).
If all instances are compliant, a message is displayed."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn'"

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
echo -e "\n+----------------+-----------------+"
echo -e "| Region        | Total Instances |"
echo -e "+----------------+-----------------+"

# Loop through each region and count EC2 instances
declare -A region_instance_count
for REGION in $regions; do
  instance_count=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'length(Reservations[*].Instances[*])' --output text)

  if [ "$instance_count" == "None" ] || [ -z "$instance_count" ]; then
    instance_count=0
  fi

  region_instance_count[$REGION]=$instance_count
  printf "| %-14s | %-15s |\n" "$REGION" "$instance_count"
done
echo "+----------------+-----------------+"
echo ""

# Track if any non-compliant instances were found
any_non_compliant=false
non_compliant_report=""

# Audit only regions with EC2 instances
for REGION in "${!region_instance_count[@]}"; do
  if [ "${region_instance_count[$REGION]}" -gt 0 ]; then

    # Fetch all instance IDs
    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text | tr ' ' '\n')

    if [ -z "$instances" ]; then
      continue
    fi

    region_non_compliant=""
    while read -r instance_id; do
      iam_role=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
        --instance-ids "$instance_id" \
        --query 'Reservations[*].Instances[*].IamInstanceProfile.Arn' --output text)

      if [ -z "$iam_role" ] || [ "$iam_role" == "None" ]; then
        any_non_compliant=true
        region_non_compliant+="$instance_id"$'\n'
      fi
    done <<< "$instances"

    if [ -n "$region_non_compliant" ]; then
      non_compliant_report+="\n${RED}Region: $REGION${NC}\n$region_non_compliant"
    fi
  fi
done

# Display audit results
if [ "$any_non_compliant" == "true" ]; then
  echo -e "\n--------------------------------------------------"
  echo -e "${RED}Non-Compliant Instances${NC}"
  echo -e "--------------------------------------------------"
  echo -e "$non_compliant_report"
  echo "--------------------------------------------------"
else
  echo -e "${GREEN}All instances across all regions are compliant.${NC}"
fi

echo "Audit completed for all regions with EC2 instances."
