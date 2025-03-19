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
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display script metadata
echo ""
echo "----------------------------------------------------------"
echo -e "${PURPLE}Description: $description${NC}"
echo -e "${PURPLE}Criteria: $criteria${NC}"
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

# Audit S3 Server Access Logging
compliant_count=0
logging_not_enabled_count=0
acl_missing_write_permission_count=0
lock_file="/tmp/s3_logging_audit_lock"

# Clear lock file
> "$lock_file"

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
    echo "$bucket|Log Delivery Group Missing WRITE Permission" >> "$lock_file"
  else
    echo "$bucket|Compliant" >> "$lock_file"
  fi
}

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

# Read results from lock file
while IFS= read -r entry; do
  bucket_name=$(echo "$entry" | cut -d '|' -f1)
  reason=$(echo "$entry" | cut -d '|' -f2)

  case "$reason" in
    "Logging Not Enabled")
      ((logging_not_enabled_count++))
      ;;
    "Log Delivery Group Missing WRITE Permission")
      ((acl_missing_write_permission_count++))
      ;;
    "Compliant")
      ((compliant_count++))
      ;;
  esac
done < "$lock_file"
rm -f "$lock_file"

# Calculate total non-compliant count
non_compliant_count=$((logging_not_enabled_count + acl_missing_write_permission_count))

# Display Audit Summary
echo ""
echo "----------------------------------------------------------"
echo -e "                      ${PURPLE}Audit Summary${NC}"
echo "----------------------------------------------------------"
printf "%-30s %-15s %-40s\n" "Status" "Bucket Count" "Reason"
echo "-------------------------------------------------------------------------------"
printf "${GREEN}%-30s${NC} %-15s %-40s\n" "Compliant" "$compliant_count" "Proper logging configuration"
printf "${RED}%-30s${NC} %-15s %-40s\n" "Non-Compliant" "$logging_not_enabled_count" "Logging Not Enabled"
printf "${RED}%-30s${NC} %-15s %-40s\n" "Non-Compliant" "$acl_missing_write_permission_count" "Log Delivery Group Missing WRITE Permission"
echo "-------------------------------------------------------------------------------"

echo ""
echo -e "${GREEN}Audit completed.${NC}"
