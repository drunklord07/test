#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Domains Running Outdated Engine Versions"
criteria="Identifies OpenSearch domains running engine versions older than the latest supported version."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.ElasticsearchVersion'"

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

# Define the latest supported OpenSearch version
latest_supported_version="2.17"  # Update this as newer versions become available

# Function to compare version numbers
version_lt() {
    [ "$1" != "$2" ] && [ "$(printf '%s\n' "$@" | sort -V | head -n 1)" = "$1" ]
}

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains
declare -A domain_mappings

# Function to check OpenSearch domain versions
check_opensearch_versions() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    total_count=0
    declare -A outdated_domains_list

    if [[ -n "$domain_names" ]]; then
        for DOMAIN in $domain_names; do
            total_count=$((total_count + 1))
            engine_version=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.ElasticsearchVersion' --output text 2>/dev/null)

            if version_lt "$engine_version" "$latest_supported_version"; then
                outdated_domains_list["$DOMAIN"]="NON-COMPLIANT (Outdated Engine Version: $engine_version)"
            fi
        done
    fi

    total_domains["$REGION"]=$total_count
    domain_mappings["$REGION"]=$(declare -p outdated_domains_list)

    printf "| %-14s | %-16s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_opensearch_versions "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing OpenSearch domains with outdated engine versions...${NC}"

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
    echo -e "${GREEN}All OpenSearch domains are running the latest supported engine versions.${NC}"
fi

echo "Audit completed for all regions."
