#!/bin/bash

# Description and Criteria
description="AWS Audit for MFA on Root Account using Trusted Advisor"
criteria="Checks whether MFA is enabled on the root account using AWS Trusted Advisor."

# Commands used
command_used="Commands Used:
  1. aws support describe-trusted-advisor-checks --region \$REGION --language en --query \"checks[?name=='MFA on Root Account'].id\"
  2. aws support refresh-trusted-advisor-check --region \$REGION --check-id \$CHECK_ID
  3. aws support describe-trusted-advisor-check-refresh-statuses --region \$REGION --check-id \$CHECK_ID
  4. aws support describe-trusted-advisor-check-result --region \$REGION --language en --check-id \$CHECK_ID --query 'result.{FlaggedResources:flaggedResources[*].metadata}'"

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

# Table Header (Instant Display)
echo "Region         | MFA Enabled"
echo "+--------------+--------------+"

declare -A mfa_status

# Step 1: Quickly gather MFA status per region and display the table
for REGION in $regions; do
    CHECK_ID=$(aws support describe-trusted-advisor-checks --region "$REGION" --profile "$PROFILE" --language en --query "checks[?name=='MFA on Root Account'].id" --output text 2>/dev/null)

    if [[ -z "$CHECK_ID" ]]; then
        continue
    fi

    # Refresh the Trusted Advisor Check
    aws support refresh-trusted-advisor-check --region "$REGION" --profile "$PROFILE" --check-id "$CHECK_ID" > /dev/null 2>&1

    # Wait for refresh completion
    while true; do
        STATUS=$(aws support describe-trusted-advisor-check-refresh-statuses --region "$REGION" --profile "$PROFILE" --check-id "$CHECK_ID" --output text 2>/dev/null)
        if [[ "$STATUS" == "success" ]]; then
            break
        fi
        sleep 5  # Wait before checking again
    done

    # Retrieve MFA check results
    flagged_resources=$(aws support describe-trusted-advisor-check-result --region "$REGION" --profile "$PROFILE" --language en --check-id "$CHECK_ID" --query 'result.flaggedResources[*].metadata' --output text 2>/dev/null)
    
    if [[ -z "$flagged_resources" ]]; then
        mfa_status["$REGION"]="Yes"
    else
        mfa_status["$REGION"]="No"
    fi

    printf "| %-14s | %-12s |\n" "$REGION" "${mfa_status[$REGION]}"
done

echo "+--------------+--------------+"
echo ""

# Step 2: MFA Compliance Audit
echo -e "${PURPLE}Checking MFA Compliance on Root Account...${NC}"
non_compliant_found=false

for REGION in "${!mfa_status[@]}"; do
    if [[ "${mfa_status[$REGION]}" == "No" ]]; then
        non_compliant_found=true
        echo -e "${RED}Region: $REGION${NC}"
        echo -e "${RED}MFA Enabled: NO${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Root account does not have MFA enabled)${NC}"
        echo "----------------------------------------------------------------"
    fi
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All AWS root accounts have MFA enabled.${NC}"
fi

echo "Audit completed for all regions."
