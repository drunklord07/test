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

# Audit S3 Bucket Ownership Settings
compliant_count=0
ownership_not_configured_count=0
object_writer_count=0
lock_file="/tmp/s3_audit_lock"

# Clear lock file
> "$lock_file"

check_ownership() {
  bucket="$1"

  # Get ownership settings
  ownership_output=$(aws s3api get-bucket-ownership-controls --bucket "$bucket" --profile "$PROFILE" --query 'OwnershipControls.Rules[*].ObjectOwnership' --output text 2>&1)

  if echo "$ownership_output" | grep -q "OwnershipControlsNotFoundError"; then
    echo "$bucket|Ownership Controls Not Configured" >> "$lock_file"
  elif echo "$ownership_output" | grep -q "ObjectWriter"; then
    echo "$bucket|Object Ownership: ObjectWriter" >> "$lock_file"
  else
    echo "$bucket|Compliant" >> "$lock_file"
  fi
}

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

# Read results from lock file
while IFS= read -r entry; do
  bucket_name=$(echo "$entry" | cut -d '|' -f1)
  reason=$(echo "$entry" | cut -d '|' -f2)

  case "$reason" in
    "Ownership Controls Not Configured")
      ((ownership_not_configured_count++))
      ;;
    "Object Ownership: ObjectWriter")
      ((object_writer_count++))
      ;;
    "Compliant")
      ((compliant_count++))
      ;;
  esac
done < "$lock_file"
rm -f "$lock_file"

# Calculate total non-compliant count
non_compliant_count=$((ownership_not_configured_count + object_writer_count))

# Display Audit Summary
echo ""
echo "----------------------------------------------------------"
echo -e "                      ${PURPLE}Audit Summary${NC}"
echo "----------------------------------------------------------"
printf "%-30s %-15s %-40s\n" "Status" "Bucket Count" "Reason for Non-Compliance"
echo "-------------------------------------------------------------------------------"
printf "${GREEN}%-30s${NC} %-15s %-40s\n" "Compliant" "$compliant_count" "Buckets with ownership properly configured"
printf "${RED}%-30s${NC} %-15s %-40s\n" "Non-Compliant" "$ownership_not_configured_count" "Ownership Controls Not Configured"
printf "${RED}%-30s${NC} %-15s %-40s\n" "Non-Compliant" "$object_writer_count" "Object Ownership: ObjectWriter"
echo "-------------------------------------------------------------------------------"

echo ""
echo -e "${GREEN}Audit completed.${NC}"
