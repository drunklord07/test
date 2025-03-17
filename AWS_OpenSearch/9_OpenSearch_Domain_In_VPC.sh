#!/bin/bash

# Description and Criteria
description="AWS Audit for Publicly Accessible OpenSearch Endpoints"
criteria="Checks if OpenSearch domains are publicly accessible by verifying if they have an endpoint URL instead of being associated with a VPC."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.Endpoint'"

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
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains
declare -A domain_mappings

# Function to check OpenSearch domain count
check_opensearch_domains() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    total_count=0
    declare -A public_domain_list

    if [[ -n "$domain_names" ]]; then
        for DOMAIN in $domain_names; do
            total_count=$((total_count + 1))
            endpoint=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.Endpoint' --output text 2>/dev/null)

            if [[ "$endpoint" != "None" && -n "$endpoint" ]]; then
                public_domain_list["$DOMAIN"]="NON-COMPLIANT (Public Endpoint)"
            fi
        done
    fi

    total_domains["$REGION"]=$total_count
    domain_mappings["$REGION"]=$(declare -p public_domain_list)

    printf "| %-14s | %-16s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_opensearch_domains "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing publicly accessible OpenSearch domains...${NC}"

non_compliant_found=false

for region in "${!domain_mappings[@]}"; do
    eval "declare -A domains_in_region=${domain_mappings[$region]}"
    
    for domain in "${!domains_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}Public OpenSearch Domain: $domain${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Public Endpoint)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}No publicly accessible OpenSearch endpoints found. All domains are COMPLIANT.${NC}"
fi

echo "Audit completed for all regions."
