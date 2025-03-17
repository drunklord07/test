#!/bin/bash

# Description and Criteria
description="AWS Audit for EC2 Instances Not Managed by AWS Systems Manager (SSM)"
criteria="Identifies running EC2 instances that are not managed by AWS SSM."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-instances --region \$REGION --filters 'Name=instance-state-name,Values=running' --query 'Reservations[*].Instances[*].InstanceId'
  2. aws ec2 describe-instances --region \$REGION --instance-ids \$INSTANCE_ID --query 'Reservations[*].Instances[].LaunchTime'
  3. aws ssm describe-instance-information --region \$REGION --instance-information-filter-list key=InstanceIds,valueSet=\$INSTANCE_ID --query 'InstanceInformationList'"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Set delay period for recently launched instances (e.g., 15 minutes)
DELAY_PERIOD_MINUTES=15

# Table Header
echo "Region         | Total Instances | Not Managed by SSM"
echo "+--------------+----------------+--------------------+"

declare -A total_instances
declare -A non_ssm_instances

# Function to check SSM managed status
check_ssm_management() {
    REGION=$1
    instances=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" --filters "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null)

    total_count=0
    non_compliant_list=()

    if [[ -n "$instances" ]]; then
        total_count=$(echo "$instances" | wc -w)

        for instance_id in $instances; do
            launch_time=$(aws ec2 describe-instances --region "$REGION" --profile "$PROFILE" --instance-ids "$instance_id" --query 'Reservations[*].Instances[].LaunchTime' --output text 2>/dev/null)
            
            # Convert launch time to Unix timestamp
            launch_time_epoch=$(date -d "$launch_time" +"%s")
            current_time_epoch=$(date +"%s")
            age_minutes=$(( (current_time_epoch - launch_time_epoch) / 60 ))

            # Skip recently launched instances
            if [[ $age_minutes -lt $DELAY_PERIOD_MINUTES ]]; then
                continue
            fi

            ssm_info=$(aws ssm describe-instance-information --region "$REGION" --profile "$PROFILE" --instance-information-filter-list key=InstanceIds,valueSet="$instance_id" --query 'InstanceInformationList' --output json 2>/dev/null)

            if [[ "$ssm_info" == "[]" ]]; then
                non_compliant_list+=("$instance_id")
            fi
        done
    fi

    total_instances["$REGION"]=$total_count
    non_ssm_instances["$REGION"]="${non_compliant_list[*]}"

    printf "| %-14s | %-14s | %-18s |\n" "$REGION" "$total_count" "${#non_compliant_list[@]}"
}

# Audit each region in parallel
for REGION in $regions; do
    check_ssm_management "$REGION" &
done

wait

echo "+--------------+----------------+--------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing EC2 Instances Not Managed by SSM...${NC}"

non_compliant_found=false

for region in "${!non_ssm_instances[@]}"; do
    IFS=' ' read -r -a instances_in_region <<< "${non_ssm_instances[$region]}"
    
    for instance in "${instances_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}EC2 Instance: $instance${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Not Managed by SSM)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All EC2 instances are managed by SSM.${NC}"
fi

echo "Audit completed for all regions."
