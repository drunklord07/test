#!/bin/bash

# Description and Criteria
description="AWS Audit for SQS Queues Without Customer-Managed KMS Encryption"
criteria="Identifies SQS queues that do not have Server-Side Encryption (SSE) enabled with a Customer Master Key (CMK)."

# Commands used
command_used="Commands Used:
  1. aws sqs list-queues --region \$REGION --query 'QueueUrls[*]'
  2. aws sqs get-queue-attributes --region \$REGION --queue-url \$QUEUE_URL --attribute-names 'KmsMasterKeyId' --query 'Attributes.KmsMasterKeyId'"

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

# Function to check SQS Encryption
check_sqs_encryption() {
    REGION=$1
    queues=$(aws sqs list-queues --region "$REGION" --profile "$PROFILE" --query 'QueueUrls[*]' --output text 2>/dev/null)

    total_count=0
    non_compliant_list=()

    if [[ -n "$queues" ]]; then
        total_count=$(echo "$queues" | wc -w)

        for queue_url in $queues; do
            kms_key=$(aws sqs get-queue-attributes --region "$REGION" --profile "$PROFILE" --queue-url "$queue_url" --attribute-names "KmsMasterKeyId" --query 'Attributes.KmsMasterKeyId' --output text 2>/dev/null)

            if [[ -z "$kms_key" || "$kms_key" == "alias/aws/sqs" ]]; then
                non_compliant_list+=("$queue_url (KMS: ${kms_key:-None})")
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
echo -e "${PURPLE}Listing SQS Queues Without Customer-Managed KMS Encryption...${NC}"

non_compliant_found=false

for region in "${!non_compliant_queues[@]}"; do
    IFS=' ' read -r -a queues_in_region <<< "${non_compliant_queues[$region]}"
    
    for queue in "${queues_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SQS Queue: $queue${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (No CMK Encryption)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SQS queues are using Customer-Managed KMS Encryption.${NC}"
fi

echo "Audit completed for all regions."
