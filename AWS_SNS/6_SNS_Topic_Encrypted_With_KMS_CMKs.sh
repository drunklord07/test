#!/bin/bash

# Description and Criteria
description="AWS Audit for SNS Topics using AWS-Managed KMS Key for Server-Side Encryption (SSE)"
criteria="Identifies SNS topics that are not using Customer-Managed KMS (CMK) for SSE."

# Commands used
command_used="Commands Used:
  1. aws sns list-topics --region \$REGION --query 'Topics[*].TopicArn'
  2. aws sns get-topic-attributes --region \$REGION --topic-arn \$TOPIC_ARN --query 'Attributes.KmsMasterKeyId'
  3. aws kms describe-key --region \$REGION --key-id \$KMS_KEY_ARN --query 'KeyMetadata.KeyManager'"

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
echo "Region         | Total Topics"
echo "+--------------+--------------+"

declare -A total_topics
declare -A non_compliant_topics

# Function to check SNS Topics for SSE compliance
check_sns_sse() {
    REGION=$1
    topics=$(aws sns list-topics --region "$REGION" --profile "$PROFILE" --query 'Topics[*].TopicArn' --output text 2>/dev/null)

    total_count=0
    non_compliant_list=()

    if [[ -n "$topics" ]]; then
        total_count=$(echo "$topics" | wc -w)

        for topic_arn in $topics; do
            kms_key_arn=$(aws sns get-topic-attributes --region "$REGION" --profile "$PROFILE" --topic-arn "$topic_arn" --query 'Attributes.KmsMasterKeyId' --output text 2>/dev/null)

            if [[ -n "$kms_key_arn" && "$kms_key_arn" != "None" ]]; then
                key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_key_arn" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

                if [[ "$key_manager" == "AWS" ]]; then
                    non_compliant_list+=("$topic_arn")
                fi
            fi
        done
    fi

    total_topics["$REGION"]=$total_count
    non_compliant_topics["$REGION"]="${non_compliant_list[*]}"

    printf "| %-14s | %-12s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_sns_sse "$REGION" &
done

wait

echo "+--------------+--------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SNS Topics using AWS-Managed KMS Keys for SSE...${NC}"

non_compliant_found=false

for region in "${!non_compliant_topics[@]}"; do
    IFS=' ' read -r -a topics_in_region <<< "${non_compliant_topics[$region]}"
    
    for topic in "${topics_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SNS Topic ARN: $topic${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Using AWS-Managed KMS Key instead of CMK)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SNS topics are using Customer-Managed KMS Keys (CMK) for SSE.${NC}"
fi

echo "Audit completed for all regions."
