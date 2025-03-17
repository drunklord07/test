#!/bin/bash

# Description and Criteria
description="AWS Audit for WAF Web ACLs"
criteria="Checks whether AWS WAF has Web ACLs configured in the account."

# Commands used
command_used="Commands Used:
  1. aws waf list-web-acls --query 'WebACLs'"

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

# Fetch AWS WAF Web ACLs
web_acls=$(aws waf list-web-acls --profile "$PROFILE" --query 'WebACLs' --output json 2>/dev/null)

# Step 1: Web ACL Compliance Audit
echo -e "${PURPLE}Checking WAF Web ACLs Configuration...${NC}"

if [[ "$web_acls" == "[]" ]]; then
    echo -e "${RED}WAF Web ACLs Configured: NO${NC}"
    echo -e "${RED}Status: NON-COMPLIANT (No Web ACLs found)${NC}"
    echo "----------------------------------------------------------------"
else
    echo -e "${GREEN}AWS WAF Web ACLs are configured.${NC}"
fi

echo "Audit completed."
