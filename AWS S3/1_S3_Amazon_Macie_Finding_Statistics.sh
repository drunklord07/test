#!/bin/bash

# Description and Criteria
description="AWS Audit: Macie Findings for S3 Buckets"
criteria="This script checks for Macie security findings across all AWS regions, summarizing total S3 buckets per region and identifying non-compliant buckets."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions
  2. aws s3api list-buckets
  3. aws macie2 get-finding-statistics
  4. aws macie2 list-findings"

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

# Get all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text)

# Header for summary table
echo "----------------------------------------------------------"
echo -e "${PURPLE}S3 Bucket Summary Per Region${NC}"
echo "----------------------------------------------------------"
printf "%-20s %-10s \n" "Region" "Total Buckets"
echo "----------------------------------------------------------"

# Iterate through each region
declare -A bucket_count
for region in $regions; do
    total_buckets=$(aws s3api list-buckets --query 'Buckets[*].Name' --output text --region "$region" | wc -w)
    bucket_count[$region]=$total_buckets
    printf "%-20s %-10s \n" "$region" "$total_buckets"
done

echo "----------------------------------------------------------"
echo ""

# Audit non-compliant buckets
echo -e "${PURPLE}Audit: Non-Compliant S3 Buckets with Macie Findings${NC}"
echo "----------------------------------------------------------"

for region in $regions; do
    findings_output=$(aws macie2 get-finding-statistics --group-by resourcesAffected.s3Bucket.name --region "$region" --query 'countsByGroup[*]' --output text 2>/dev/null)
    
    if [[ -z "$findings_output" ]]; then
        continue
    fi

    echo -e "${GREEN}Region: $region${NC}"
    
    while read -r count bucket_name; do
        echo -e "${RED}Non-Compliant Bucket: $bucket_name (Findings: $count)${NC}"
        
        # Get finding types for the bucket
        finding_types_output=$(aws macie2 get-finding-statistics --group-by type --finding-criteria criterion={resourcesAffected.s3Bucket.name={eq="$bucket_name"}} --region "$region" --query 'countsByGroup[*]' --output text 2>/dev/null)
        
        if [[ -n "$finding_types_output" ]]; then
            echo "  Security Finding Types:"
            echo "$finding_types_output" | while read -r f_count f_type; do
                echo "    - $f_type ($f_count occurrences)"
            done
        fi

        # Get finding IDs for the bucket
        finding_ids=$(aws macie2 list-findings --finding-criteria criterion={resourcesAffected.s3Bucket.name={eq="$bucket_name"}} --region "$region" --query 'FindingIds[*]' --output text 2>/dev/null)
        
        if [[ -n "$finding_ids" ]]; then
            echo "  Finding IDs:"
            echo "    $finding_ids"
        fi

        echo "----------------------------------------------------------"
    done <<< "$findings_output"
done

echo ""
echo -e "${GREEN}Audit completed.${NC}"
