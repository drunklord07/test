#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Domain Encryption at Rest"
criteria="This script checks if Amazon OpenSearch domains have encryption at rest enabled."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.EncryptionAtRestOptions.Enabled'"

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
declare -A encryption_status

# Function to check OpenSearch domain encryption at rest
check_encryption_at_rest() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    if [[ -z "$domain_names" ]]; then
        echo "| $REGION | No domains found |"
        return
    fi

    checked_count=0
    declare -A domain_encryption

    for DOMAIN in $domain_names; do
        checked_count=$((checked_count + 1))
        encryption_enabled=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.EncryptionAtRestOptions.Enabled' --output text 2>/dev/null)

        if [[ -n "$encryption_enabled" ]]; then
            domain_encryption["$DOMAIN"]="$encryption_enabled"
        fi
    done

    total_domains["$REGION"]=$checked_count
    encryption_status["$REGION"]=$(declare -p domain_encryption)

    printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_encryption_at_rest "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
violation_found=false

echo -e "${PURPLE}Checking for OpenSearch domains without encryption at rest...${NC}"

for region in "${!encryption_status[@]}"; do
    eval "declare -A domains_in_region=${encryption_status[$region]}"
    
    unencrypted_domains=()
    for domain in "${!domains_in_region[@]}"; do
        encryption="${domains_in_region[$domain]}"
        
        # Check if encryption at rest is disabled (false)
        if [[ "$encryption" == "false" ]]; then
            unencrypted_domains+=("$domain")
        fi
    done

    if [[ ${#unencrypted_domains[@]} -gt 0 ]]; then
        violation_found=true
        echo -e "${RED}Region: $region${NC}"
        echo "OpenSearch Domains without Encryption at Rest:"
        for domain in "${unencrypted_domains[@]}"; do
            echo -e "${RED}- $domain${NC}"
        done
        echo "----------------------------------------------------------------"
    fi
done

if [[ "$violation_found" = false ]]; then
    echo -e "${GREEN}All OpenSearch domains have encryption at rest enabled. No issues found.${NC}"
fi

echo "Audit completed for all regions."
