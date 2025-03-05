#!/bin/bash

# Description and Criteria
description="AWS Audit: S3 Bucket Cross-Account Access Compliance"
criteria="This script checks if S3 bucket policies allow access to untrusted AWS accounts."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws s3api get-bucket-policy"

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

# Define trusted AWS account IDs
TRUSTED_ACCOUNTS=("111122223333" "444455556666")  # Update with your trusted AWS account IDs

# Get total number of S3 buckets
TOTAL_BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output json | jq length)

if [ -z "$TOTAL_BUCKETS" ]; then
  echo "ERROR: Unable to retrieve S3 bucket count."
  exit 1
fi

echo "Total number of S3 buckets in AWS account: $TOTAL_BUCKETS"
echo ""

# Check cross-account access compliance for each bucket
NON_COMPLIANT_BUCKETS=()
BUCKETS=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)

for BUCKET in $BUCKETS; do
  POLICY_OUTPUT=$(aws s3api get-bucket-policy --profile "$PROFILE" --bucket "$BUCKET" --query Policy --output text 2>&1)

  if echo "$POLICY_OUTPUT" | grep -q "NoSuchBucketPolicy"; then
    continue  # Skip buckets without policies
  fi

  # Extract AWS Account IDs from the policy
  ACCOUNT_IDS=$(echo "$POLICY_OUTPUT" | grep -oP '"AWS":\s*"arn:aws:iam::\K\d+' | sort -u)

  for ACCOUNT in $ACCOUNT_IDS; do
    if [[ ! " ${TRUSTED_ACCOUNTS[@]} " =~ " $ACCOUNT " ]]; then
      NON_COMPLIANT_BUCKETS+=("$BUCKET (Untrusted Account: $ACCOUNT)")
    fi
  done
done

# Display Audit Summary
echo "----------------------------------------------------------"
echo "Audit Summary:"
echo "----------------------------------------------------------"
echo "Total S3 Buckets: $TOTAL_BUCKETS"
if [ ${#NON_COMPLIANT_BUCKETS[@]} -eq 0 ]; then
  echo "All S3 buckets have compliant cross-account access settings."
else
  echo "Non-Compliant S3 Buckets (Untrusted Cross-Account Access):"
  for BUCKET in "${NON_COMPLIANT_BUCKETS[@]}"; do
    echo "- $BUCKET"
  done
fi
echo "----------------------------------------------------------"
echo "Audit completed."
