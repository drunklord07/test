#!/bin/bash

# Description and Criteria
description="AWS Audit: Macie Findings for S3 Buckets"
criteria="This script checks for Macie security findings across all AWS S3 buckets, identifying non-compliant buckets."

# Commands used
command_used="Commands Used:
  1. aws s3api list-buckets
  2. aws macie2 get-finding-statistics
  3. aws macie2 list-findings"

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
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get list of all S3 buckets
buckets=$(aws s3api list-buckets --profile "$PROFILE" --query 'Buckets[*].Name' --output text)
total_buckets=$(echo "$buckets" | wc -w)

echo -e "${PURPLE}Total S3 Buckets: ${GREEN}$total_buckets${NC}"
echo "----------------------------------------------------------"

# Check for Macie findings (Parallel Execution)
echo -e "${PURPLE}Audit: Non-Compliant S3 Buckets with Macie Findings${NC}"
echo "----------------------------------------------------------"

non_compliant_buckets=()
audit_bucket() {
    bucket_name=$1

    # Get Macie finding count for the bucket
    findings_count=$(aws macie2 get-finding-statistics \
        --group-by resourcesAffected.s3Bucket.name \
        --profile "$PROFILE" \
        --query "countsByGroup[?groupId=='$bucket_name'].count" \
        --output text 2>/dev/null)

    # If findings exist, gather details
    if [[ "$findings_count" -gt 0 ]]; then
        non_compliant_buckets+=("$bucket_name")

        echo -e "${RED}Non-Compliant Bucket: $bucket_name (Findings: $findings_count)${NC}"

        # Get finding types for the bucket
        finding_types_output=$(aws macie2 get-finding-statistics \
            --group-by type \
            --finding-criteria criterion={resourcesAffected.s3Bucket.name={eq="$bucket_name"}} \
            --profile "$PROFILE" \
            --query 'countsByGroup[*]' \
            --output text 2>/dev/null)

        if [[ -n "$finding_types_output" ]]; then
            echo "  Security Finding Types:"
            echo "$finding_types_output" | while read -r f_count f_type; do
                echo "    - $f_type ($f_count occurrences)"
            done
        fi

        # Get finding IDs for the bucket
        finding_ids=$(aws macie2 list-findings \
            --finding-criteria criterion={resourcesAffected.s3Bucket.name={eq="$bucket_name"}} \
            --profile "$PROFILE" \
            --query 'FindingIds[*]' \
            --output text 2>/dev/null)

        if [[ -n "$finding_ids" ]]; then
            echo "  Finding IDs:"
            echo "    $finding_ids"
        fi

        echo "----------------------------------------------------------"
    fi
}

# Run audits in parallel
for bucket in $buckets; do
    audit_bucket "$bucket" &
done

wait  # Wait for all background tasks to finish

# Final message
if [[ ${#non_compliant_buckets[@]} -eq 0 ]]; then
    echo -e "${GREEN}All S3 buckets are compliant.${NC}"
else
    echo -e "${RED}Non-compliant buckets detected: ${#non_compliant_buckets[@]}${NC}"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
