#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Server Access Logging Configuration"
criteria="This script checks if Server Access Logging is enabled for all S3 buckets and verifies if the Log Delivery Group has write permissions."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-bucket-logging
  3. aws s3api get-bucket-acl"

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

# Fetch all S3 buckets
echo -e "${GREEN}Fetching list of S3 buckets...${NC}"
BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)

if [ -z "$BUCKETS" ]; then
  echo -e "${RED}No S3 buckets found in the AWS account.${NC}"
  exit 1
fi

echo "----------------------------------------------------------"
echo -e "${GREEN}Total S3 Buckets Found:${NC}"
echo "----------------------------------------------------------"
for BUCKET in $BUCKETS; do
  echo "- $BUCKET"
done
echo "----------------------------------------------------------"

# Audit S3 Server Access Logging
echo -e "${GREEN}Checking Server Access Logging configuration for each bucket...${NC}"
NON_COMPLIANT_BUCKETS=()

for BUCKET in $BUCKETS; do
  LOGGING_TARGET=$(aws s3api get-bucket-logging --profile "$PROFILE" --bucket "$BUCKET" --query 'LoggingEnabled.TargetBucket' --output text 2>/dev/null)
  
  if [ "$LOGGING_TARGET" == "None" ]; then
    echo -e "${RED}Bucket '$BUCKET' does not have Server Access Logging enabled.${NC}"
    NON_COMPLIANT_BUCKETS+=("$BUCKET")
    continue
  fi

  ACL_PERMISSION=$(aws s3api get-bucket-acl --profile "$PROFILE" --bucket "$BUCKET" --query 'Grants[?(Grantee.URI==`http://acs.amazonaws.com/groups/s3/LogDelivery`)].Permission' --output text 2>/dev/null)

  if [[ "$ACL_PERMISSION" != *"WRITE"* ]]; then
    echo -e "${RED}Bucket '$BUCKET' has Server Access Logging enabled but lacks Log Delivery Group WRITE permission.${NC}"
    NON_COMPLIANT_BUCKETS+=("$BUCKET")
  else
    echo -e "${GREEN}Bucket '$BUCKET' has Server Access Logging enabled and Log Delivery Group WRITE permission.${NC}"
  fi
done

# Display Non-Compliant Buckets
if [ ${#NON_COMPLIANT_BUCKETS[@]} -ne 0 ]; then
  echo ""
  echo "----------------------------------------------------------"
  echo -e "${RED}Non-Compliant S3 Buckets (Missing Logging or Permissions):${NC}"
  echo "----------------------------------------------------------"
  for BUCKET in "${NON_COMPLIANT_BUCKETS[@]}"; do
    echo -e "${RED}- $BUCKET${NC}"
  done
  echo "----------------------------------------------------------"
else
  echo -e "${GREEN}All S3 buckets have proper logging configuration.${NC}"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
