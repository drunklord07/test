#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Cross-Account Access Policies"
criteria="This script checks if Amazon OpenSearch domains have an access policy allowing cross-account access from any AWS account or IAM ARN."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.AccessPolicies'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
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
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains
declare -A policy_mappings

# Function to check OpenSearch domain access policies
check_access_policies() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    if [[ -z "$domain_names" ]]; then
        echo "| $REGION | No domains found |"
        return
    fi

    checked_count=0
    declare -A domain_policies

    for DOMAIN in $domain_names; do
        checked_count=$((checked_count + 1))
        access_policy=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.AccessPolicies' --output text 2>/dev/null)

        if [[ -n "$access_policy" ]]; then
            domain_policies["$DOMAIN"]="$access_policy"
        fi
    done

    total_domains["$REGION"]=$checked_count
    policy_mappings["$REGION"]=$(declare -p domain_policies)

    printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_access_policies "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
violation_found=false

echo -e "${PURPLE}Listing OpenSearch domains with cross-account access policies...${NC}"

for region in "${!policy_mappings[@]}"; do
    eval "declare -A domains_in_region=${policy_mappings[$region]}"
    
    found_domains=()
    for domain in "${!domains_in_region[@]}"; do
        policy="${domains_in_region[$domain]}"

        # Extract all "Principal" ARNs from the policy (without jq)
        principal_arns=$(echo "$policy" | grep -o '"AWS": *"[^"]*"' | awk -F '"' '{print $4}')

        if [[ -n "$principal_arns" ]]; then
            found_domains+=("$domain")
            echo -e "${RED}Region: $region${NC}"
            echo "OpenSearch Domain: $domain"
            echo "Cross-Account Access:"
            echo "$principal_arns"
            echo "----------------------------------------------------------------"
            violation_found=true
        fi
    done
done

if [[ "$violation_found" = false ]]; then
    echo -e "${GREEN}No cross-account access detected in OpenSearch domains.${NC}"
fi

echo "Audit completed for all regions."
