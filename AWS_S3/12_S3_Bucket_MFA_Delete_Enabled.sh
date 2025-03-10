#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Bucket MFA Delete Status"
criteria="This script checks if MFA Delete is enabled for each S3 bucket."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-bucket-versioning"

# Display script metadata
echo ""
echo "----------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
echo "----------------------------------------------------------"
echo ""

# Set AWS CLI profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get total number of S3 buckets
TOTAL_BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output json | jq length)

if [ -z "$TOTAL_BUCKETS" ]; then
  echo "ERROR: Unable to retrieve S3 bucket count."
  exit 1
fi

echo "Total number of S3 buckets in AWS account: $TOTAL_BUCKETS"
echo ""

# Check MFA Delete status for each bucket
NON_COMPLIANT_BUCKETS=()
BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)

for BUCKET in $BUCKETS; do
  OUTPUT=$(aws s3api get-bucket-versioning --profile "$PROFILE" --bucket "$BUCKET" --query 'MFADelete' --output json 2>&1)

  if [ "$OUTPUT" == "null" ]; then
    NON_COMPLIANT_BUCKETS+=("$BUCKET")
  fi
done

# Display Audit Summary
echo "----------------------------------------------------------"
echo "Audit Summary:"
echo "----------------------------------------------------------"
echo "Total S3 Buckets: $TOTAL_BUCKETS"
if [ ${#NON_COMPLIANT_BUCKETS[@]} -eq 0 ]; then
  echo "All S3 buckets have MFA Delete enabled."
else
  echo "Non-Compliant S3 Buckets (MFA Delete Disabled):"
  for BUCKET in "${NON_COMPLIANT_BUCKETS[@]}"; do
    echo "- $BUCKET"
  done
fi
echo "----------------------------------------------------------"
echo "Audit completed."
