#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Bucket Ownership Controls"
criteria="This script checks if the S3 Object Ownership feature is enabled for each S3 bucket in the AWS account."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-bucket-ownership-controls"

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

# Fetch all S3 bucket names
echo -e "${GREEN}Retrieving list of S3 buckets...${NC}"
bucket_list=$(aws s3api list-buckets --query 'Buckets[*].Name' --profile "$PROFILE" --output text)

if [ -z "$bucket_list" ]; then
  echo -e "${RED}No S3 buckets found in this AWS account.${NC}"
  exit 0
fi

# Display all S3 buckets
echo ""
echo "----------------------------------------------------------"
echo -e "${PURPLE}List of S3 Buckets:${NC}"
echo "----------------------------------------------------------"
for bucket in $bucket_list; do
  echo "$bucket"
done
echo "----------------------------------------------------------"
echo ""

# Check bucket ownership settings
non_compliant_buckets=()

echo -e "${GREEN}Checking S3 Object Ownership settings for each bucket...${NC}"
for bucket in $bucket_list; do
  ownership_output=$(aws s3api get-bucket-ownership-controls --bucket "$bucket" --profile "$PROFILE" --query 'OwnershipControls.Rules[*].ObjectOwnership' --output text 2>&1)

  if echo "$ownership_output" | grep -q "OwnershipControlsNotFoundError"; then
    non_compliant_buckets+=("$bucket (Ownership Controls Not Configured)")
  elif echo "$ownership_output" | grep -q "ObjectWriter"; then
    non_compliant_buckets+=("$bucket (Object Ownership: ObjectWriter)")
  fi
done

# Display Non-Compliant Buckets
if [ ${#non_compliant_buckets[@]} -gt 0 ]; then
  echo ""
  echo "----------------------------------------------------------"
  echo -e "${RED}Non-Compliant S3 Buckets (Object Ownership Not Configured Properly):${NC}"
  echo "----------------------------------------------------------"
  for bucket in "${non_compliant_buckets[@]}"; do
    echo -e "${RED}$bucket${NC}"
  done
  echo "----------------------------------------------------------"
else
  echo -e "${GREEN}All S3 buckets have proper ownership controls configured.${NC}"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
