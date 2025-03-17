#!/bin/bash

# Description and Criteria
description="AWS Audit for SNS Subscriptions with Unwanted Subscribers"
criteria="Identifies SNS subscriptions with endpoints that should not be subscribed to a given SNS topic."

# Commands used
command_used="Commands Used:
  1. aws sns list-subscriptions --region \$REGION --query 'Subscriptions[*].SubscriptionArn'
  2. aws sns get-subscription-attributes --region \$REGION --subscription-arn \$SUBSCRIPTION_ARN"

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
echo "Region         | Total Subscriptions"
echo "+--------------+--------------------+"

declare -A total_subscriptions
declare -A unwanted_subscribers

# Define unwanted subscriber emails or protocols
UNWANTED_ENDPOINTS=("spam@example.com" "untrusted@domain.com")
UNWANTED_PROTOCOLS=("sms")

# Function to check SNS Subscription Attributes
check_sns_subscriptions() {
    REGION=$1
    subscriptions=$(aws sns list-subscriptions --region "$REGION" --profile "$PROFILE" --query 'Subscriptions[*].SubscriptionArn' --output text 2>/dev/null)

    total_count=0
    unwanted_list=()

    if [[ -n "$subscriptions" ]]; then
        total_count=$(echo "$subscriptions" | wc -w)

        for subscription_arn in $subscriptions; do
            attributes=$(aws sns get-subscription-attributes --region "$REGION" --profile "$PROFILE" --subscription-arn "$subscription_arn" --query 'Attributes' --output text 2>/dev/null)
            
            endpoint=$(echo "$attributes" | grep -oP '(?<=Endpoint\s).*')
            protocol=$(echo "$attributes" | grep -oP '(?<=Protocol\s).*')

            if [[ " ${UNWANTED_ENDPOINTS[@]} " =~ " $endpoint " || " ${UNWANTED_PROTOCOLS[@]} " =~ " $protocol " ]]; then
                unwanted_list+=("$subscription_arn")
            fi
        done
    fi

    total_subscriptions["$REGION"]=$total_count
    unwanted_subscribers["$REGION"]="${unwanted_list[*]}"

    printf "| %-14s | %-18s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_sns_subscriptions "$REGION" &
done

wait

echo "+--------------+--------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing SNS subscriptions with unwanted subscribers...${NC}"

non_compliant_found=false

for region in "${!unwanted_subscribers[@]}"; do
    IFS=' ' read -r -a subscriptions_in_region <<< "${unwanted_subscribers[$region]}"
    
    for subscription in "${subscriptions_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}SNS Subscription ARN: $subscription${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Unwanted Subscriber Detected)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All SNS subscriptions have appropriate subscribers.${NC}"
fi

echo "Audit completed for all regions."
