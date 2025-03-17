#!/bin/bash

# Description and Criteria
description="AWS Audit for SNS Topics Publicly Accessible for Subscription"
criteria="Identifies SNS topics with policies that allow public ('*') subscription access."

# Commands used
command_used="Commands Used:
  1. aws sns list-topics --region \$REGION --query 'Topics[*].TopicArn'
  2. aws sns get-topic-attributes --region \$REGION --topic-arn \$TOPIC_ARN --query 'Attributes.Policy'"

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

# Function to check SNS Topics for public subscription access
check_sns_public_subscription() {
    REGION=$1
    topics=$(aws sns list-topics --region "$REGION" --profile "$PROFILE" --query 'Topics[*].TopicArn' --output text 2>/dev/null)

    total_count=0
    non_compliant_list=()

    if [[ -n "$topics" ]]; then
        total_count=$(echo "$topics" | wc -w)

        for topic_arn in $topics; do
            policy=$(aws sns get-topic-attributes --region "$REGION" --profile "$PROFILE" --topic-arn "$topic_arn" --query 'Attributes.Policy' --output text 2>/dev/null)

            if [[ -n "$policy" && "$policy" != "None" ]]; then
                effect_allow=$(echo "$policy" | grep -oP '"Effect":\s*"\K[^"]+')
                principal=$(echo "$policy" | grep -oP '"Principal":\s*{\s*"AWS":\s*"\K[^"]+')
                actions=$(echo "$policy" | grep -oP '"Action":\s*\[\s*\K[^]]+')

                if [[ "$effect_allow" == "Allow" && "$principal" == "*" && "$actions" =~ "SNS:Subscribe" && "$actions" =~ "SNS:Receive" ]]; then
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
    check_sns_public_subscription "$REGION" &
done

wait

echo "+--------------+--------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SNS Topics with Public Subscription Access...${NC}"

non_compliant_found=false

for region in "${!non_compliant_topics[@]}"; do
    IFS=' ' read -r -a topics_in_region <<< "${non_compliant_topics[$region]}"
    
    for topic in "${topics_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SNS Topic ARN: $topic${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Publicly Accessible for Subscription)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SNS topics have restricted subscription access.${NC}"
fi

echo "Audit completed for all regions."
