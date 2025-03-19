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
buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --profile "$PROFILE" --output text)

# Count total buckets
total_buckets=$(echo "$buckets" | wc -w)

if [ "$total_buckets" -eq 0 ]; then
  echo -e "${RED}No S3 buckets found in this AWS account.${NC}"
  exit 0
fi

echo -e "${PURPLE}Total S3 Buckets: ${GREEN}$total_buckets${NC}"
echo "----------------------------------------------------------"

# Audit S3 Bucket Ownership Settings with Parallel Execution
non_compliant_buckets=()
lock_file="/tmp/s3_audit_lock"

check_ownership() {
  bucket="$1"
  ownership_output=$(aws s3api get-bucket-ownership-controls --bucket "$bucket" --profile "$PROFILE" --query 'OwnershipControls.Rules[*].ObjectOwnership' --output text 2>&1)

  if echo "$ownership_output" | grep -q "OwnershipControlsNotFoundError"; then
    echo "$bucket (Ownership Controls Not Configured)" >> "$lock_file"
  elif echo "$ownership_output" | grep -q "ObjectWriter"; then
    echo "$bucket (Object Ownership: ObjectWriter)" >> "$lock_file"
  fi
}

# Cleanup lock file if exists
> "$lock_file"

# Run checks in parallel
for bucket in $buckets; do
  check_ownership "$bucket" &
  
  # Limit parallel jobs to prevent AWS API throttling
  while [ "$(jobs -r | wc -l)" -ge 10 ]; do
    sleep 1
  done
done

# Wait for all background processes to finish
wait

# Read non-compliant buckets from the lock file
mapfile -t non_compliant_buckets < "$lock_file"
rm -f "$lock_file"

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
