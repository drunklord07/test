#!/bin/bash

# Description and Criteria
description="AWS Audit for SQS Queues Without Server-Side Encryption (SSE)"
criteria="Identifies SQS queues where 'SqsManagedSseEnabled' is 'false', indicating data is not encrypted at rest."

# Commands used
command_used="Commands Used:
  1. aws sqs list-queues --region \$REGION --query 'QueueUrls[*]'
  2. aws sqs get-queue-attributes --region \$REGION --queue-url \$QUEUE_URL --attribute-names 'SqsManagedSseEnabled' 'KmsMasterKeyId' --query 'Attributes'"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display script metadata
echo ""
echo "---------------------------------------------------------------------"
echo -e "${PURPLE}Description: $description${NC}"
echo ""
echo -e "${PURPLE}Criteria: $criteria${NC}"
echo ""
echo -e "${PURPLE}$command_used${NC}"
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
echo "Region         | Total Queues"
echo "+--------------+--------------+"

declare -A total_queues
declare -A non_compliant_queues

# Function to check SQS Encryption status
check_sqs_encryption() {
    REGION=$1
    queues=$(aws sqs list-queues --region "$REGION" --profile "$PROFILE" --query 'QueueUrls[*]' --output text 2>/dev/null)

    total_count=0
    non_compliant_list=()

    if [[ -n "$queues" ]]; then
        total_count=$(echo "$queues" | wc -w)

        for queue_url in $queues; do
            attributes_json=$(aws sqs get-queue-attributes --region "$REGION" --profile "$PROFILE" --queue-url "$queue_url" --attribute-names "SqsManagedSseEnabled" "KmsMasterKeyId" --query 'Attributes' --output json 2>/dev/null)

            if echo "$attributes_json" | grep -q '"SqsManagedSseEnabled": "false"'; then
                non_compliant_list+=("$queue_url")
            fi
        done
    fi

    total_queues["$REGION"]=$total_count
    non_compliant_queues["$REGION"]="${non_compliant_list[*]}"

    printf "| %-14s | %-12s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_sqs_encryption "$REGION" &
done

wait

echo "+--------------+--------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SQS Queues Without Server-Side Encryption...${NC}"

non_compliant_found=false

for region in "${!non_compliant_queues[@]}"; do
    IFS=' ' read -r -a queues_in_region <<< "${non_compliant_queues[$region]}"
    
    for queue in "${queues_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SQS Queue URL: $queue${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Encryption Disabled)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SQS queues are encrypted with SSE.${NC}"
fi

echo "Audit completed for all regions."
