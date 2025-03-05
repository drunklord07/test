#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances with Multiple Network Interfaces (ENIs)"
criteria="This script identifies Amazon EC2 instances that have multiple attached Elastic Network Interfaces (ENIs) in each AWS region.
Instances with multiple ENIs are marked as 'Non-Compliant' (printed in red) as they may have complex networking or security implications."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws ec2 describe-instances --region \$REGION --query 'Reservations[*].Instances[*].InstanceId'
  3. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[*].NetworkInterfaces[*].[NetworkInterfaceId,Attachment.Status]'"

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

# Set AWS CLI profile (change this as needed)
PROFILE="my-role"

# Validate if the AWS profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo -e "\n+----------------+----------------+"
echo "| Region         | Instances Found |"
echo "+----------------+----------------+"

# Audit each region for instances with multiple ENIs
declare -A region_instance_count
for REGION in $regions; do
  instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text)

  instance_count=$(echo "$instances" | wc -w)
  region_instance_count[$REGION]=$instance_count

  printf "| %-14s | %-14s |\n" "$REGION" "$instance_count"
done
echo "+----------------+----------------+"
echo ""

# Show instances with multiple ENIs
for REGION in "${!region_instance_count[@]}"; do
  if [ "${region_instance_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" \
      --query 'Reservations[*].Instances[*].InstanceId' --output text)

    for INSTANCE_ID in $instances; do
      # Get the list of network interfaces for the instance
      enis=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[*].Instances[*].NetworkInterfaces[*].[NetworkInterfaceId,Attachment.Status]' --output text)

      eni_count=$(echo "$enis" | wc -l)

      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Instance ID: $INSTANCE_ID"
      echo "Attached ENIs:"

      while read -r ENI_ID STATUS; do
        echo "  - $ENI_ID ($STATUS)"
      done <<< "$enis"

      if [ "$eni_count" -gt 1 ]; then
        echo -e "Status: ${RED}Non-Compliant (Multiple ENIs detected – Review networking setup)${NC}"
      else
        echo -e "Status: ${GREEN}Compliant (Single ENI)${NC}"
      fi

      echo "--------------------------------------------------"
    done
  fi
done

echo "Audit completed for all regions."
