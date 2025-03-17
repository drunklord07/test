#!/bin/bash

# Description and Criteria
description="AWS Audit for SSM Parameter Encryption Compliance"
criteria="Identifies SSM parameters that contain sensitive information but are not encrypted."

# Commands used
command_used="Commands Used:
  1. aws ssm describe-parameters --region \$REGION --query 'Parameters[*].[Name,Type]' --output text"

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

# Table Header (Before Audit)
echo "Region         | Total Parameters"
echo "+--------------+----------------+"

# Function to check SSM parameters
check_ssm_parameters() {
    REGION=$1
    parameters=$(aws ssm describe-parameters --region "$REGION" --profile "$PROFILE" --output text --query 'Parameters[*].[Name,Type]' 2>/dev/null)

    total_count=0
    non_compliant_found=false

    if [[ -n "$parameters" ]]; then
        while read -r param_name param_type; do
            if [[ -n "$param_name" && -n "$param_type" ]]; then
                total_count=$((total_count + 1))

                # Check for non-encrypted sensitive parameters
                if [[ "$param_type" == "String" || "$param_type" == "StringList" ]]; then
                    echo -e "${RED}Region: $REGION${NC}"
                    echo -e "${RED}SSM Parameter: $param_name${NC}"
                    echo -e "${RED}Status: NON-COMPLIANT (Not Encrypted)${NC}"
                    echo "----------------------------------------------------------------"
                    non_compliant_found=true
                fi
            fi
        done <<< "$parameters"
    fi

    printf "| %-14s | %-16s |\n" "$REGION" "$total_count"

    # If no non-compliant parameters were found
    if [[ "$non_compliant_found" == false ]]; then
        echo -e "${GREEN}Region: $REGION - All SSM parameters are encrypted.${NC}"
        echo "----------------------------------------------------------------"
    fi
}

# Audit each region in parallel
for REGION in $regions; do
    check_ssm_parameters "$REGION" &
done

wait

echo "+--------------+----------------+"
echo ""
echo "Audit completed for all regions."
