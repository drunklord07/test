#!/bin/bash

# Description and Criteria
description="AWS Audit for Exposed IAM Access Keys using Trusted Advisor"
criteria="Checks whether any IAM access keys are publicly exposed using AWS Trusted Advisor."

# Commands used
command_used="Commands Used:
  1. aws support describe-trusted-advisor-checks --region \$REGION --language en --query \"checks[?name=='Exposed Access Keys'].id\"
  2. aws support refresh-trusted-advisor-check --region \$REGION --check-id \$CHECK_ID
  3. aws support describe-trusted-advisor-check-refresh-statuses --region \$REGION --check-id \$CHECK_ID
  4. aws support describe-trusted-advisor-check-result --region \$REGION --language en --check-id \$CHECK_ID"

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
echo "Region         | Exposed Keys"
echo "+--------------+----------------+"

declare -A exposed_keys

# Step 1: Quickly gather exposed keys per region and display the table
for REGION in $regions; do
    CHECK_ID=$(aws support describe-trusted-advisor-checks --region "$REGION" --profile "$PROFILE" --language en --query "checks[?name=='Exposed Access Keys'].id" --output text 2>/dev/null)

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

    # Retrieve flagged IAM Access Keys
    flagged_keys=$(aws support describe-trusted-advisor-check-result --region "$REGION" --profile "$PROFILE" --language en --check-id "$CHECK_ID" --query 'result.flaggedResources[*].resourceId' --output text 2>/dev/null)
    
    count=$(echo "$flagged_keys" | wc -w)
    exposed_keys["$REGION"]=$count
    printf "| %-14s | %-14s |\n" "$REGION" "$count"
done

echo "+--------------+----------------+"
echo ""

# Step 2: Exposed Access Keys Audit
echo -e "${PURPLE}Checking Exposed IAM Access Keys Compliance...${NC}"
non_compliant_found=false

for REGION in "${!exposed_keys[@]}"; do
    if [[ "${exposed_keys[$REGION]}" -gt 0 ]]; then
        non_compliant_found=true
        echo -e "${RED}Region: $REGION${NC}"
        echo -e "${RED}Exposed Keys: ${exposed_keys[$REGION]}${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Exposed IAM Access Keys Found)${NC}"
        echo "----------------------------------------------------------------"
    fi
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All IAM access keys are secure, no public exposure detected.${NC}"
fi

echo "Audit completed for all regions."
