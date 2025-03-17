#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Domains with Outdated TLS Security Policies"
criteria="Identifies OpenSearch domains using TLS security policies lower than TLS 1.2."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.DomainEndpointOptions.TLSSecurityPolicy'"

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

# Define the minimum required TLS policy
minimum_tls_policy="Policy-Min-TLS-1-2-2019-07"

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains
declare -A domain_mappings

# Function to check TLS policy version for OpenSearch domains
check_tls_versions() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    total_count=0
    declare -A outdated_tls_list

    if [[ -n "$domain_names" ]]; then
        for DOMAIN in $domain_names; do
            total_count=$((total_count + 1))
            tls_version=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.DomainEndpointOptions.TLSSecurityPolicy' --output text 2>/dev/null)

            if [[ "$tls_version" != "$minimum_tls_policy" ]]; then
                outdated_tls_list["$DOMAIN"]="NON-COMPLIANT (TLS Version: $tls_version)"
            fi
        done
    fi

    total_domains["$REGION"]=$total_count
    domain_mappings["$REGION"]=$(declare -p outdated_tls_list)

    printf "| %-14s | %-16s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_tls_versions "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing OpenSearch domains with outdated TLS policies...${NC}"

non_compliant_found=false

for region in "${!domain_mappings[@]}"; do
    eval "declare -A domains_in_region=${domain_mappings[$region]}"
    
    for domain in "${!domains_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}OpenSearch Domain: $domain${NC}"
        echo -e "${RED}Status: ${domains_in_region[$domain]}${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All OpenSearch domains are using the latest TLS security policy.${NC}"
fi

echo "Audit completed for all regions."
