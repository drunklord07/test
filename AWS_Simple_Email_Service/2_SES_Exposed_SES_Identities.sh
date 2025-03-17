#!/bin/bash

# Description and Criteria
description="AWS Audit for SES Identities with Public Sending Authorization Policies"
criteria="Identifies SES identities (domains and email addresses) that have overly permissive sending authorization policies, allowing anyone to send emails on their behalf."

# Commands used
command_used="Commands Used:
  1. aws ses list-identities --region \$REGION
  2. aws ses list-identity-policies --region \$REGION --identity \$IDENTITY
  3. aws ses get-identity-policies --region \$REGION --identity \$IDENTITY --policy-names \$POLICY_NAME"

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
echo "Region         | SES Identities | Policies Found"
echo "+--------------+---------------+---------------+"

declare -A total_identities
declare -A public_policies

# Function to check SES Sending Authorization Policies
check_ses_policies() {
    REGION=$1
    identities=$(aws ses list-identities --region "$REGION" --profile "$PROFILE" --query 'Identities' --output text 2>/dev/null)

    total_count=0
    public_policies_list=()

    if [[ -n "$identities" ]]; then
        total_count=$(echo "$identities" | wc -w)

        for identity in $identities; do
            policy_names=$(aws ses list-identity-policies --region "$REGION" --profile "$PROFILE" --identity "$identity" --query 'PolicyNames' --output text 2>/dev/null)

            if [[ -n "$policy_names" ]]; then
                for policy_name in $policy_names; do
                    policy_document=$(aws ses get-identity-policies --region "$REGION" --profile "$PROFILE" --identity "$identity" --policy-names "$policy_name" --output text 2>/dev/null)

                    if echo "$policy_document" | grep -q '"Principal": "*"' || echo "$policy_document" | grep -q '"AWS": "*"'; then
                        if ! echo "$policy_document" | grep -q '"Condition"'; then
                            public_policies_list+=("$identity ($policy_name)")
                        fi
                    fi
                done
            fi
        done
    fi

    total_identities["$REGION"]=$total_count
    public_policies["$REGION"]="${public_policies_list[*]}"

    printf "| %-14s | %-13s | %-13s |\n" "$REGION" "$total_count" "${#public_policies_list[@]}"
}

# Audit each region in parallel
for REGION in $regions; do
    check_ses_policies "$REGION" &
done

wait

echo "+--------------+---------------+---------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SES identities with overly permissive sending authorization policies...${NC}"

non_compliant_found=false

for region in "${!public_policies[@]}"; do
    IFS=' ' read -r -a identities_in_region <<< "${public_policies[$region]}"
    
    for identity_policy in "${identities_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SES Identity: $identity_policy${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Public Sending Authorization)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SES identities have restricted sending authorization policies.${NC}"
fi

echo "Audit completed for all regions."
