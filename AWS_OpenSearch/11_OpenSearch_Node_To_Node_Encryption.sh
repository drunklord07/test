#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Domains with Node-to-Node Encryption Disabled"
criteria="Checks if OpenSearch domains have Node-to-Node Encryption disabled, which is a security risk."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.NodeToNodeEncryptionOptions.Enabled'"

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

# Function to check OpenSearch domain encryption
check_opensearch_encryption() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    total_count=0
    declare -A non_encrypted_list

    if [[ -n "$domain_names" ]]; then
        for DOMAIN in $domain_names; do
            total_count=$((total_count + 1))
            encryption_status=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.NodeToNodeEncryptionOptions.Enabled' --output text 2>/dev/null)

            if [[ "$encryption_status" == "False" || "$encryption_status" == "false" ]]; then
                non_encrypted_list["$DOMAIN"]="NON-COMPLIANT (Node-to-Node Encryption Disabled)"
            fi
        done
    fi

    total_domains["$REGION"]=$total_count
    domain_mappings["$REGION"]=$(declare -p non_encrypted_list)

    printf "| %-14s | %-16s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_opensearch_encryption "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing OpenSearch domains with Node-to-Node Encryption disabled...${NC}"

non_compliant_found=false

for region in "${!domain_mappings[@]}"; do
    eval "declare -A domains_in_region=${domain_mappings[$region]}"
    
    for domain in "${!domains_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}OpenSearch Domain: $domain${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (Node-to-Node Encryption Disabled)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All OpenSearch domains have Node-to-Node Encryption enabled.${NC}"
fi

echo "Audit completed for all regions."
