#!/bin/bash

# Description and Criteria
description="AWS Audit for Amazon Kinesis Data Streams Encryption"
criteria="Checks if Server-Side Encryption (SSE) is enabled for all Kinesis data streams across AWS regions."

# Commands used
command_used="Commands Used:
  aws kinesis list-streams --region \$REGION --output text
  aws kinesis describe-stream --region \$REGION --stream-name \$STREAM --query 'StreamDescription.EncryptionType' --output text"

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
echo "Region         | Stream Name               | Encryption Type"
echo "+--------------+--------------------------+----------------+"

declare -A stream_encryption

# Step 1: Fetch Kinesis Data Streams Per Region
for REGION in $regions; do
    stream_names=$(aws kinesis list-streams --region "$REGION" --profile "$PROFILE" --output text 2>/dev/null)

    if [[ -z "$stream_names" ]]; then
        continue
    fi

    # Read each stream
    for STREAM in $stream_names; do
        encryption_type=$(aws kinesis describe-stream --region "$REGION" --profile "$PROFILE" --stream-name "$STREAM" --query 'StreamDescription.EncryptionType' --output text 2>/dev/null)

        [[ "$encryption_type" == "None" || -z "$encryption_type" ]] && encryption_type="NONE"

        stream_encryption["$REGION|$STREAM"]="$encryption_type"

        printf "| %-14s | %-24s | %-14s |\n" "$REGION" "$STREAM" "$encryption_type"
    done
done

echo "+--------------+--------------------------+----------------+"
echo ""

# Step 2: Audit Summary
echo "---------------------------------------------------------------------"
echo "Audit Results (Amazon Kinesis Data Streams Encryption)"
echo "---------------------------------------------------------------------"
if [[ ${#stream_encryption[@]} -eq 0 ]]; then
    echo "No Kinesis data streams found or all are unencrypted."
else
    for key in "${!stream_encryption[@]}"; do
        IFS="|" read -r REGION STREAM_NAME <<< "$key"
        ENCRYPTION="${stream_encryption[$key]}"
        echo "$REGION | Stream: $STREAM_NAME | Encryption: $ENCRYPTION"
    done
fi

echo "---------------------------------------------------------------------"
echo "Audit completed for all regions."
