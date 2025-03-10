#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Block Public Access Configuration"
criteria="This script checks if S3 Block Public Access is enabled at the account level."

# Commands used
command_used="Commands Used:
  1. aws s3control get-public-access-block"

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

# Fetch AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query 'Account' --output text)

if [ -z "$ACCOUNT_ID" ]; then
  echo -e "${RED}ERROR: Unable to retrieve AWS Account ID.${NC}"
  exit 1
fi

echo -e "${GREEN}Checking S3 Block Public Access settings for AWS account: $ACCOUNT_ID...${NC}"

# Check S3 Block Public Access settings
OUTPUT=$(aws s3control get-public-access-block --profile "$PROFILE" --account-id "$ACCOUNT_ID" --query 'PublicAccessBlockConfiguration' --output json 2>&1)

if echo "$OUTPUT" | grep -q "NoSuchPublicAccessBlockConfiguration"; then
  echo -e "${RED}S3 Block Public Access is NOT configured for AWS account: $ACCOUNT_ID${NC}"
  NON_COMPLIANT=true
else
  echo -e "${GREEN}S3 Block Public Access is properly configured for AWS account: $ACCOUNT_ID${NC}"
  NON_COMPLIANT=false
fi

# Display Audit Summary
echo ""
echo "----------------------------------------------------------"
echo -e "${GREEN}Audit Summary:${NC}"
echo "----------------------------------------------------------"
if [ "$NON_COMPLIANT" = true ]; then
  echo -e "${RED}AWS Account $ACCOUNT_ID does NOT have S3 Block Public Access enabled.${NC}"
else
  echo -e "${GREEN}AWS Account $ACCOUNT_ID has S3 Block Public Access enabled.${NC}"
fi
echo "----------------------------------------------------------"
echo -e "${GREEN}Audit completed.${NC}"
