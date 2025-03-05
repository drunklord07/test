#!/bin/bash

# Description and Criteria
description="AWS Audit: IAM Password Policy Configuration"
criteria="This script checks if a custom IAM password policy is configured for the AWS account and verifies compliance with security best practices."

# Commands used
command_used="Commands Used:
  1. aws iam get-account-password-policy --query 'PasswordPolicy' --output text"

# Color codes
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'  # No color

# Display script metadata
echo ""
echo "----------------------------------------------------------"
echo -e "${PURPLE}Description: $description${NC}"
echo ""
echo -e "${PURPLE}Criteria: $criteria${NC}"
echo ""
echo -e "${PURPLE}$command_used${NC}"
echo "----------------------------------------------------------"
echo ""

# Set AWS CLI profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo -e "${RED}ERROR: AWS profile '$PROFILE' does not exist.${NC}"
  exit 1
fi

# Check IAM password policy
echo -e "${GREEN}Checking IAM password policy...${NC}"
POLICY_OUTPUT=$(aws iam get-account-password-policy --query 'PasswordPolicy' --output text --profile "$PROFILE" 2>&1)

if [[ "$POLICY_OUTPUT" == *"NoSuchEntity"* ]]; then
    echo -e "${RED}No custom IAM password policy found. Your AWS account is not fully protected against unauthorized access.${NC}"
    exit 1
fi

# Check compliance for each policy requirement
echo ""
echo -e "${PURPLE}IAM Password Policy Compliance Check:${NC}"
echo "----------------------------------------------------------"

# Minimum Password Length
MIN_LENGTH=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text --profile "$PROFILE")
if [[ "$MIN_LENGTH" -ge 14 ]]; then
    echo -e "${GREEN}✔ Minimum Password Length: $MIN_LENGTH (Compliant)${NC}"
else
    echo -e "${RED}✖ Minimum Password Length: $MIN_LENGTH (Non-Compliant)${NC}"
fi

# Require Lowercase Characters
LOWERCASE=$(aws iam get-account-password-policy --query 'PasswordPolicy.RequireLowercaseCharacters' --output text --profile "$PROFILE")
if [[ "$LOWERCASE" == "True" ]]; then
    echo -e "${GREEN}✔ Requires Lowercase Characters: Enabled (Compliant)${NC}"
else
    echo -e "${RED}✖ Requires Lowercase Characters: Disabled (Non-Compliant)${NC}"
fi

# Require Uppercase Characters
UPPERCASE=$(aws iam get-account-password-policy --query 'PasswordPolicy.RequireUppercaseCharacters' --output text --profile "$PROFILE")
if [[ "$UPPERCASE" == "True" ]]; then
    echo -e "${GREEN}✔ Requires Uppercase Characters: Enabled (Compliant)${NC}"
else
    echo -e "${RED}✖ Requires Uppercase Characters: Disabled (Non-Compliant)${NC}"
fi

# Require Numbers
NUMBERS=$(aws iam get-account-password-policy --query 'PasswordPolicy.RequireNumbers' --output text --profile "$PROFILE")
if [[ "$NUMBERS" == "True" ]]; then
    echo -e "${GREEN}✔ Requires Numbers: Enabled (Compliant)${NC}"
else
    echo -e "${RED}✖ Requires Numbers: Disabled (Non-Compliant)${NC}"
fi

# Require Symbols
SYMBOLS=$(aws iam get-account-password-policy --query 'PasswordPolicy.RequireSymbols' --output text --profile "$PROFILE")
if [[ "$SYMBOLS" == "True" ]]; then
    echo -e "${GREEN}✔ Requires Symbols: Enabled (Compliant)${NC}"
else
    echo -e "${RED}✖ Requires Symbols: Disabled (Non-Compliant)${NC}"
fi

# Maximum Password Age
MAX_AGE=$(aws iam get-account-password-policy --query 'PasswordPolicy.MaxPasswordAge' --output text --profile "$PROFILE")
if [[ "$MAX_AGE" == "None" ]]; then
    echo -e "${RED}✖ Maximum Password Age: Not Set (Non-Compliant)${NC}"
elif [[ "$MAX_AGE" -le 90 ]]; then
    echo -e "${GREEN}✔ Maximum Password Age: $MAX_AGE days (Compliant)${NC}"
else
    echo -e "${RED}✖ Maximum Password Age: $MAX_AGE days (Non-Compliant)${NC}"
fi

# Password Reuse Prevention
REUSE=$(aws iam get-account-password-policy --query 'PasswordPolicy.PasswordReusePrevention' --output text --profile "$PROFILE")
if [[ "$REUSE" == "None" ]]; then
    echo -e "${RED}✖ Password Reuse Prevention: Not Set (Non-Compliant)${NC}"
else
    echo -e "${GREEN}✔ Password Reuse Prevention: $REUSE passwords remembered (Compliant)${NC}"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
