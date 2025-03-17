#!/bin/bash

# Description and Criteria
description="AWS Audit for SES Identities Without DKIM Signatures"
criteria="Identifies SES email identities (domains and addresses) that do not have DKIM enabled, leaving them vulnerable to phishing attacks."

# Commands used
command_used="Commands Used:
  1. aws ses list-identities --region \$REGION
  2. aws ses get-identity-dkim-attributes --region \$REGION --identities \$IDENTITIES"

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

# Table Header
echo "Region         | SES Identities"
echo "+--------------+--------------+"

declare -A total_identities
declare -A dkim_failures

# Function to check SES DKIM settings
check_ses_dkim() {
    REGION=$1
    identities=$(aws ses list-identities --region "$REGION" --profile "$PROFILE" --query 'Identities' --output text 2>/dev/null)

    total_count=0
    failed_dkim_list=()

    if [[ -n "$identities" ]]; then
        total_count=$(echo "$identities" | wc -w)
        
        # Fetch DKIM attributes
        dkim_output=$(aws ses get-identity-dkim-attributes --region "$REGION" --profile "$PROFILE" --identities $identities --output text 2>/dev/null)

        # Process output
        while read -r identity dkim_enabled _; do
            if [[ "$dkim_enabled" == "False" ]]; then
                failed_dkim_list+=("$identity")
            fi
        done <<< "$dkim_output"
    fi

    total_identities["$REGION"]=$total_count
    dkim_failures["$REGION"]="${failed_dkim_list[*]}"

    printf "| %-14s | %-12s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_ses_dkim "$REGION" &
done

wait

echo "+--------------+--------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SES identities with missing DKIM signatures...${NC}"

non_compliant_found=false

for region in "${!dkim_failures[@]}"; do
    IFS=' ' read -r -a identities_in_region <<< "${dkim_failures[$region]}"
    
    for identity in "${identities_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SES Identity: $identity${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (DKIM Not Enabled)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SES identities have DKIM enabled.${NC}"
fi

echo "Audit completed for all regions."
