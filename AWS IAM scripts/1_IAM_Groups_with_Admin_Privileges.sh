#!/bin/bash

# Description and Criteria
description="AWS Audit: IAM Groups Count & Non-Compliant IAM Groups with Administrator Access"
criteria="This script retrieves the total number of IAM groups in the AWS account and identifies IAM groups with AdministratorAccess permissions."

# Commands used
command_used="Commands Used:
  1. aws iam list-groups --profile <PROFILE> --query 'Groups[*].GroupName' --output text
  2. aws iam list-attached-group-policies --profile <PROFILE> --group-name <GROUP_NAME> --query 'AttachedPolicies[*].PolicyName' --output text"

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

# List all IAM groups
IAM_GROUPS=$(aws iam list-groups --profile "$PROFILE" --query 'Groups[*].GroupName' --output text)

if [ -z "$IAM_GROUPS" ]; then
    echo -e "${RED}No IAM groups found in the AWS account.${NC}"
    exit 0
fi

# Count total IAM groups
TOTAL_GROUPS=$(echo "$IAM_GROUPS" | wc -l)

# Print total IAM groups
echo -e "${GREEN}Total IAM Groups: $TOTAL_GROUPS${NC}"
echo ""
echo -e "${GREEN}IAM Group${NC}"
echo "--------------------------------"

# Print each IAM group
for GROUP in $IAM_GROUPS; do
    echo "| $GROUP |"
done

echo "--------------------------------"
echo ""

# Check for non-compliant IAM groups
echo -e "${RED}Non-Compliant IAM Groups with Administrator Access:${NC}"
echo "---------------------------------------------------"

NON_COMPLIANT=()

for GROUP in $IAM_GROUPS; do
    POLICIES=$(aws iam list-attached-group-policies --profile "$PROFILE" --group-name "$GROUP" --query 'AttachedPolicies[*].PolicyName' --output text)

    if echo "$POLICIES" | grep -q "AdministratorAccess"; then
        NON_COMPLIANT+=("$GROUP")
    fi
done

if [ ${#NON_COMPLIANT[@]} -eq 0 ]; then
    echo -e "${GREEN}No IAM groups found with Administrator Access.${NC}"
else
    for GROUP in "${NON_COMPLIANT[@]}"; do
        echo "- $GROUP"
    done
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
