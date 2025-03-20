#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Bucket ACL for Authenticated Users (WRITE Access)"
criteria="This script checks if any S3 bucket grants WRITE access to the 'Authenticated Users' group."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-bucket-acl"

# Color codes
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
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

# Audit S3 Bucket ACLs for WRITE Access
compliant_count=0
non_compliant_buckets=()
lock_file="/tmp/s3_acl_audit_lock"

# Clear lock file
> "$lock_file"

check_acl() {
  bucket="$1"

  # Get bucket ACL settings
  acl_output=$(aws s3api get-bucket-acl --bucket "$bucket" --profile "$PROFILE" --query 'Grants[?(Grantee.URI==`http://acs.amazonaws.com/groups/global/AuthenticatedUsers`)].Permission' --output json 2>&1)

  if echo "$acl_output" | grep -q "WRITE"; then
    echo "$bucket|Non-Compliant (WRITE access granted to Authenticated Users)" >> "$lock_file"
  else
    echo "$bucket|Compliant" >> "$lock_file"
  fi
}

# Run checks in parallel
for bucket in $buckets; do
  check_acl "$bucket" &
  
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
    "Non-Compliant (WRITE access granted to Authenticated Users)")
      non_compliant_buckets+=("$bucket_name")
      ;;
    "Compliant")
      ((compliant_count++))
      ;;
  esac
done < "$lock_file"
rm -f "$lock_file"

# Calculate total non-compliant count
non_compliant_count=${#non_compliant_buckets[@]}

# Display Audit Summary
echo ""
echo "----------------------------------------------------------"
echo -e "                      ${PURPLE}Audit Summary${NC}"
echo "----------------------------------------------------------"
printf "%-30s %-15s %-40s\n" "Status" "Bucket Count" "Reason"
echo "-------------------------------------------------------------------------------"
printf "${GREEN}%-30s${NC} %-15s %-40s\n" "Compliant" "$compliant_count" "Buckets without WRITE access for Authenticated Users"
printf "${RED}%-30s${NC} %-15s %-40s\n" "Non-Compliant" "$non_compliant_count" "WRITE access granted to Authenticated Users"
echo "-------------------------------------------------------------------------------"

# Display Non-Compliant Buckets
if [ "$non_compliant_count" -gt 0 ]; then
  echo ""
  echo "----------------------------------------------------------"
  echo -e "           ${RED}Non-Compliant S3 Buckets${NC}"
  echo "----------------------------------------------------------"
  for bucket in "${non_compliant_buckets[@]}"; do
    echo -e "${RED}- $bucket${NC}"
  done
  echo "----------------------------------------------------------"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
