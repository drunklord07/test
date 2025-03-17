#!/bin/bash

# Description and Criteria
description="AWS Audit for WAFv2 Web ACL Logging Compliance"
criteria="Checks whether AWS WAFv2 Web ACLs have logging enabled."

# Commands used
command_used="Commands Used:
  1. aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs[*].ARN'
  2. aws wafv2 get-logging-configuration --resource-arn WEB_ACL_ARN --query 'LoggingConfiguration'"

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

# Fetch Web ACL ARNs (REGIONAL scope)
web_acl_arns=$(aws wafv2 list-web-acls --scope REGIONAL --profile "$PROFILE" --query 'WebACLs[*].ARN' --output text 2>/dev/null)

# Step 1: Web ACL Logging Compliance Audit
echo -e "${PURPLE}Checking WAFv2 Web ACL Logging Configuration...${NC}"
non_compliant_found=false

if [[ -z "$web_acl_arns" ]]; then
    echo -e "${RED}No Web ACLs found in REGIONAL scope.${NC}"
    echo "----------------------------------------------------------------"
else
    for acl_arn in $web_acl_arns; do
        # Get Logging Configuration
        logging_config=$(aws wafv2 get-logging-configuration --resource-arn "$acl_arn" --profile "$PROFILE" --query 'LoggingConfiguration' --output text 2>/dev/null)

        if [[ "$logging_config" == "None" ]]; then
            non_compliant_found=true
            echo -e "${RED}Web ACL: $acl_arn${NC}"
            echo -e "${RED}Status: NON-COMPLIANT (Logging Not Enabled)${NC}"
            echo "----------------------------------------------------------------"
        fi
    done
fi

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All WAFv2 Web ACLs have logging enabled.${NC}"
fi

echo "Audit completed."
