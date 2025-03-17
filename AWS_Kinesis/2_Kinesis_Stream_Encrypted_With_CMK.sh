#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Kinesis Data Streams Encryption Key"
criteria="Checks if Kinesis data streams are encrypted and whether they use AWS-managed or customer-managed KMS keys."

# Commands used
command_used="Commands Used:
  aws kinesis list-streams --region \$REGION --query 'StreamNames'
  aws kinesis describe-stream --region \$REGION --stream-name \$STREAM --query 'StreamDescription.KeyId'"

# Display script metadata
echo ""
echo "---------------------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
echo "---------------------------------------------------------------------"
echo ""

# Set AWS CLI profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | Stream Name               | Encryption Key"
echo "+--------------+--------------------------+--------------------------+"

found_streams=0

# Step 1: Fetch Kinesis Data Streams Per Region
for REGION in $regions; do
    stream_names=$(aws kinesis list-streams --region "$REGION" --profile "$PROFILE" --query 'StreamNames' --output text 2>/dev/null)

    if [[ -z "$stream_names" ]]; then
        continue
    fi

    found_streams=1

    for STREAM in $stream_names; do
        key_id=$(aws kinesis describe-stream --region "$REGION" --profile "$PROFILE" --stream-name "$STREAM" --query 'StreamDescription.KeyId' --output text 2>/dev/null)

        if [[ -z "$key_id" || "$key_id" == "None" ]]; then
            key_id="NULL (SSE Disabled)"
        fi

        printf "| %-14s | %-24s | %-24s |\n" "$REGION" "$STREAM" "$key_id"
    done
done

echo "+--------------+--------------------------+--------------------------+"
echo ""

# Step 2: Audit Summary
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Kinesis Data Streams Encryption Key)"
echo "---------------------------------------------------------------------"
if [[ $found_streams -eq 0 ]]; then
    echo "No Kinesis data streams found or all are unencrypted."
else
    echo "Audit completed. Review the table above for findings."
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
