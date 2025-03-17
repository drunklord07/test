#!/bin/bash

# Description and Criteria
description="AWS Audit for SES Identities with Cross-Account Sending Authorization Policies"
criteria="Identifies SES identities (domains and email addresses) that have sending authorization policies allowing access to unknown AWS accounts."

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

# Define trusted AWS account IDs (Replace these with your trusted accounts)
trusted_accounts=("123456789012" "234567890123" "345678901234")

# Table Header
echo "Region         | SES Identities | Policies Found"
echo "+--------------+---------------+---------------+"

declare -A total_identities
declare -A untrusted_policies

# Function to check SES Cross-Account Sending Authorization Policies
check_ses_policies() {
    REGION=$1
    identities=$(aws ses list-identities --region "$REGION" --profile "$PROFILE" --query 'Identities' --output text 2>/dev/null)

    total_count=0
    untrusted_policies_list=()

    if [[ -n "$identities" ]]; then
        total_count=$(echo "$identities" | wc -w)

        for identity in $identities; do
            policy_names=$(aws ses list-identity-policies --region "$REGION" --profile "$PROFILE" --identity "$identity" --query 'PolicyNames' --output text 2>/dev/null)

            if [[ -n "$policy_names" ]]; then
                for policy_name in $policy_names; do
                    policy_document=$(aws ses get-identity-policies --region "$REGION" --profile "$PROFILE" --identity "$identity" --policy-names "$policy_name" --output text 2>/dev/null)

                    # Extract AWS Account IDs from the policy document
                    account_ids=$(echo "$policy_document" | grep -oE 'arn:aws:iam::[0-9]{12}:root' | cut -d':' -f5)

                    for account_id in $account_ids; do
                        if [[ ! " ${trusted_accounts[@]} " =~ " $account_id " ]]; then
                            untrusted_policies_list+=("$identity ($policy_name) - Untrusted Account: $account_id")
                        fi
                    done
                done
            fi
        done
    fi

    total_identities["$REGION"]=$total_count
    untrusted_policies["$REGION"]="${untrusted_policies_list[*]}"

    printf "| %-14s | %-13s | %-13s |\n" "$REGION" "$total_count" "${#untrusted_policies_list[@]}"
}

# Audit each region in parallel
for REGION in $regions; do
    check_ses_policies "$REGION" &
done

wait

echo "+--------------+---------------+---------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SES identities with untrusted cross-account access...${NC}"

non_compliant_found=false

for region in "${!untrusted_policies[@]}"; do
    IFS=' ' read -r -a identities_in_region <<< "${untrusted_policies[$region]}"
    
    for identity_policy in "${identities_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SES Identity: $identity_policy${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Untrusted Cross-Account Access)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SES identities have restricted cross-account access.${NC}"
fi

echo "Audit completed for all regions."
