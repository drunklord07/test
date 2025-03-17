#!/bin/bash

# Description and Criteria
description="AWS Audit for SES Identities with Pending Verification Status"
criteria="Identifies SES identities (domains and email addresses) that have not been successfully verified in Amazon SES."

# Commands used
command_used="Commands Used:
  1. aws ses list-identities --region \$REGION
  2. aws ses get-identity-verification-attributes --region \$REGION --identities \$IDENTITY"

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
echo "Region         | SES Identities | Pending Verifications"
echo "+--------------+---------------+-----------------------+"

declare -A total_identities
declare -A pending_verifications

# Function to check SES Identity Verification Status
check_ses_verification() {
    REGION=$1
    identities=$(aws ses list-identities --region "$REGION" --profile "$PROFILE" --query 'Identities' --output text 2>/dev/null)

    total_count=0
    pending_list=()

    if [[ -n "$identities" ]]; then
        total_count=$(echo "$identities" | wc -w)

        for identity in $identities; do
            verification_status=$(aws ses get-identity-verification-attributes --region "$REGION" --profile "$PROFILE" --identities "$identity" --query "VerificationAttributes[\"$identity\"].VerificationStatus" --output text 2>/dev/null)

            if [[ "$verification_status" == "Pending" ]]; then
                pending_list+=("$identity")
            fi
        done
    fi

    total_identities["$REGION"]=$total_count
    pending_verifications["$REGION"]="${pending_list[*]}"

    printf "| %-14s | %-13s | %-21s |\n" "$REGION" "$total_count" "${#pending_list[@]}"
}

# Audit each region in parallel
for REGION in $regions; do
    check_ses_verification "$REGION" &
done

wait

echo "+--------------+---------------+-----------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SES identities with pending verification status...${NC}"

non_compliant_found=false

for region in "${!pending_verifications[@]}"; do
    IFS=' ' read -r -a identities_in_region <<< "${pending_verifications[$region]}"
    
    for identity in "${identities_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SES Identity: $identity${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Pending Verification)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SES identities are verified.${NC}"
fi

echo "Audit completed for all regions."
