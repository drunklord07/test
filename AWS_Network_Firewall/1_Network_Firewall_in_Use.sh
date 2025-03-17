#!/bin/bash

# Description and Criteria
description="AWS Audit for VPCs to check if AWS Network Firewall is implemented."
criteria="Identifies VPCs without AWS Network Firewall, which is a security risk."

# Commands used
command_used="Commands Used:
  aws ec2 describe-vpcs --region \$REGION --query 'Vpcs[*].VpcId'
  aws network-firewall list-firewalls --region \$REGION --vpc-ids <vpc_id> --query 'Firewalls'"

# Display script metadata
echo ""
echo "---------------------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
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
echo "Region         | Number of VPCs"
echo "+--------------+---------------+"

declare -A region_vpc_count
declare -A non_compliant_vpcs

# Step 1: Fetch VPCs Per Region
for REGION in $regions; do
    vpcs=$(aws ec2 describe-vpcs --region "$REGION" --profile "$PROFILE" --query 'Vpcs[*].VpcId' --output text 2>/dev/null)

    if [[ -z "$vpcs" ]]; then
        continue
    fi

    vpc_count=0
    for VPC_ID in $vpcs; do
        ((vpc_count++))
        firewalls=$(aws network-firewall list-firewalls --region "$REGION" --profile "$PROFILE" --vpc-ids "$VPC_ID" --query 'Firewalls' --output text 2>/dev/null)

        if [[ -z "$firewalls" || "$firewalls" == "None" ]]; then
            non_compliant_vpcs["$REGION|$VPC_ID"]="No Network Firewall"
        fi
    done

    region_vpc_count["$REGION"]=$vpc_count
    printf "| %-14s | %-13s |\n" "$REGION" "$vpc_count"
done

echo "+--------------+---------------+"
echo ""

# Step 2: Audit for Non-Compliant VPCs
echo "---------------------------------------------------------------------"
echo "Audit Results (VPCs without AWS Network Firewall)"
echo "---------------------------------------------------------------------"
if [[ ${#non_compliant_vpcs[@]} -eq 0 ]]; then
    echo "All VPCs have AWS Network Firewall implemented."
else
    for key in "${!non_compliant_vpcs[@]}"; do
        IFS="|" read -r REGION VPC_ID <<< "$key"
        echo "$REGION | VPC ID: $VPC_ID | ${non_compliant_vpcs[$key]}"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
