#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Bucket Object Lock Configuration Compliance"
criteria="This script checks if Object Lock is enabled for all S3 buckets."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-object-lock-configuration"

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

# Check Object Lock configuration for each bucket
NON_COMPLIANT_BUCKETS=()
BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)

for BUCKET in $BUCKETS; do
  LOCK_STATUS=$(aws s3api get-object-lock-configuration --profile "$PROFILE" --bucket "$BUCKET" --query 'ObjectLockConfiguration.ObjectLockEnabled' --output text 2>&1)

  if echo "$LOCK_STATUS" | grep -q "ObjectLockConfigurationNotFoundError"; then
    NON_COMPLIANT_BUCKETS+=("$BUCKET (Object Lock Not Enabled)")
  fi
done

# Display Audit Summary
echo "----------------------------------------------------------"
echo "Audit Summary:"
echo "----------------------------------------------------------"
echo "Total S3 Buckets: $TOTAL_BUCKETS"
if [ ${#NON_COMPLIANT_BUCKETS[@]} -eq 0 ]; then
  echo "All S3 buckets have Object Lock enabled."
else
  echo "Non-Compliant S3 Buckets (Object Lock Not Enabled):"
  for BUCKET in "${NON_COMPLIANT_BUCKETS[@]}"; do
    echo "- $BUCKET"
  done
fi
echo "----------------------------------------------------------"
echo "Audit completed."
