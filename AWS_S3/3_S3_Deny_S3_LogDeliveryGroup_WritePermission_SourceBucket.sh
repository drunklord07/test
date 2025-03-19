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
buckets=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)

# Count total buckets
total_buckets=$(echo "$buckets" | wc -w)

if [ "$total_buckets" -eq 0 ]; then
  echo -e "${RED}No S3 buckets found in the AWS account.${NC}"
  exit 0
fi

echo -e "${PURPLE}Total S3 Buckets: ${GREEN}$total_buckets${NC}"
echo "----------------------------------------------------------"

# Audit S3 Server Access Logging with Parallel Execution
non_compliant_buckets=()
lock_file="/tmp/s3_logging_audit_lock"

check_logging() {
  bucket="$1"

  # Check if Server Access Logging is enabled
  logging_target=$(aws s3api get-bucket-logging --profile "$PROFILE" --bucket "$bucket" --query 'LoggingEnabled.TargetBucket' --output text 2>/dev/null)
  
  if [ -z "$logging_target" ] || [ "$logging_target" == "None" ]; then
    echo "$bucket|Logging Not Enabled" >> "$lock_file"
    return
  fi

  # Check if Log Delivery Group has WRITE permission
  acl_permission=$(aws s3api get-bucket-acl --profile "$PROFILE" --bucket "$bucket" --query 'Grants[?(Grantee.URI==`http://acs.amazonaws.com/groups/s3/LogDelivery`)].Permission' --output text 2>/dev/null)

  if [[ "$acl_permission" != *"WRITE"* ]]; then
    echo "$bucket|Logging Enabled but Missing WRITE Permission" >> "$lock_file"
  fi
}

# Cleanup lock file if exists
> "$lock_file"

# Run checks in parallel
for bucket in $buckets; do
  check_logging "$bucket" &
  
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
non_compliant_count=${#non_compliant_buckets[@]}

echo ""
echo -e "${PURPLE}Total Non-Compliant Buckets: ${RED}$non_compliant_count${NC}"
echo "----------------------------------------------------------"

if [ "$non_compliant_count" -gt 0 ]; then
  printf "%-40s %-40s\n" "Bucket Name" "Reason for Non-Compliance"
  echo "---------------------------------------------------------------------------------------------"
  
  for entry in "${non_compliant_buckets[@]}"; do
    bucket_name=$(echo "$entry" | cut -d '|' -f1)
    bucket_reason=$(echo "$entry" | cut -d '|' -f2)

    printf "%-40s %-40s\n" "$bucket_name" "$bucket_reason"
  done

  echo "---------------------------------------------------------------------------------------------"
else
  echo -e "${GREEN}All S3 buckets have proper logging configuration.${NC}"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
