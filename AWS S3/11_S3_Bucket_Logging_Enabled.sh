#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Bucket Server Access Logging"
criteria="This script checks if Server Access Logging is enabled for each S3 bucket."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-bucket-logging"

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

# Get total number of S3 buckets
TOTAL_BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output json | jq length)

if [ -z "$TOTAL_BUCKETS" ]; then
  echo -e "${RED}ERROR: Unable to retrieve S3 bucket count.${NC}"
  exit 1
fi

echo -e "${GREEN}Total number of S3 buckets in AWS account: $TOTAL_BUCKETS${NC}"
echo ""

# Check bucket logging configuration
NON_COMPLIANT_BUCKETS=()
BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)

for BUCKET in $BUCKETS; do
  OUTPUT=$(aws s3api get-bucket-logging --profile "$PROFILE" --bucket "$BUCKET" --query 'LoggingEnabled' --output json 2>&1)

  if [ "$OUTPUT" == "null" ]; then
    NON_COMPLIANT_BUCKETS+=("$BUCKET")
  fi
done

# Display Audit Summary
echo "----------------------------------------------------------"
echo -e "${GREEN}Audit Summary:${NC}"
echo "----------------------------------------------------------"
echo -e "${GREEN}Total S3 Buckets: $TOTAL_BUCKETS${NC}"
if [ ${#NON_COMPLIANT_BUCKETS[@]} -eq 0 ]; then
  echo -e "${GREEN}All S3 buckets have Server Access Logging enabled.${NC}"
else
  echo -e "${RED}Non-Compliant S3 Buckets (Server Access Logging Disabled):${NC}"
  for BUCKET in "${NON_COMPLIANT_BUCKETS[@]}"; do
    echo -e "${RED}- $BUCKET${NC}"
  done
fi
echo "----------------------------------------------------------"
echo -e "${GREEN}Audit completed.${NC}"
