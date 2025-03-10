#!/bin/bash

# Description and Criteria
description="AWS Audit: IAM Users with Administrator Access"
criteria="This script lists all IAM users and identifies users with the AdministratorAccess policy attached."

# Commands used
command_used="Commands Used:
  1. aws iam list-users --query 'Users[*].UserName' --output text
  2. aws iam list-attached-user-policies --user-name <USER_NAME> --query 'AttachedPolicies[*].PolicyName' --output text"

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

# Get list of IAM users
echo -e "${GREEN}Fetching IAM users...${NC}"
IAM_USERS=$(aws iam list-users --profile "$PROFILE" --query 'Users[*].UserName' --output text 2>/dev/null)

if [ -z "$IAM_USERS" ]; then
    echo -e "${RED}No IAM users found.${NC}"
    exit 0
fi

echo ""
echo -e "${PURPLE}Total IAM Users: $(echo "$IAM_USERS" | wc -w)${NC}"
echo ""
echo "IAM User List:"
echo "---------------------------------"
for user in $IAM_USERS; do
    echo "| $user"
done
echo "---------------------------------"
echo ""

# Check which users have AdministratorAccess
NON_COMPLIANT_USERS=()

for user in $IAM_USERS; do
    POLICIES=$(aws iam list-attached-user-policies --user-name "$user" --profile "$PROFILE" --query 'AttachedPolicies[*].PolicyName' --output text 2>/dev/null)
    
    if echo "$POLICIES" | grep -qw "AdministratorAccess"; then
        NON_COMPLIANT_USERS+=("$user")
    fi
done

# Display non-compliant users separately
if [ ${#NON_COMPLIANT_USERS[@]} -eq 0 ]; then
    echo -e "${GREEN}No IAM users found with AdministratorAccess.${NC}"
else
    echo ""
    echo -e "${RED}Non-Compliant IAM Users with Administrator Access:${NC}"
    echo "---------------------------------"
    for user in "${NON_COMPLIANT_USERS[@]}"; do
        echo -e "${RED}| $user${NC}"
    done
    echo "---------------------------------"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
