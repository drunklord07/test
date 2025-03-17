#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Domains Using AWS-Managed KMS Keys"
criteria="Checks if OpenSearch domains are using AWS-managed KMS keys instead of Customer-Managed Keys (CMKs) for encryption at rest."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.EncryptionAtRestOptions.KmsKeyId'
  3. aws kms describe-key --region \$REGION --key-id \$KMS_ARN --query 'KeyMetadata.KeyManager'"

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
    declare -A aws_managed_list

    if [[ -n "$domain_names" ]]; then
        for DOMAIN in $domain_names; do
            total_count=$((total_count + 1))
            kms_key=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.EncryptionAtRestOptions.KmsKeyId' --output text 2>/dev/null)

            if [[ "$kms_key" != "None" && -n "$kms_key" ]]; then
                key_manager=$(aws kms describe-key --region "$REGION" --profile "$PROFILE" --key-id "$kms_key" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)

                if [[ "$key_manager" == "AWS" ]]; then
                    aws_managed_list["$DOMAIN"]="NON-COMPLIANT (AWS-Managed Key)"
                fi
            fi
        done
    fi

    total_domains["$REGION"]=$total_count
    domain_mappings["$REGION"]=$(declare -p aws_managed_list)

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
echo -e "${PURPLE}Listing OpenSearch domains using AWS-managed KMS keys...${NC}"

non_compliant_found=false

for region in "${!domain_mappings[@]}"; do
    eval "declare -A domains_in_region=${domain_mappings[$region]}"
    
    for domain in "${!domains_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}OpenSearch Domain: $domain${NC}"
        echo -e "${RED}Status: NON-COMPLIANT (AWS-Managed Key)${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All OpenSearch domains are using Customer-Managed Keys (CMKs).${NC}"
fi

echo "Audit completed for all regions."
