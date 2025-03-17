#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Cluster Instance Types"
criteria="This script checks whether the Amazon OpenSearch clusters are using instance types compliant with organizational policies."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.ElasticsearchClusterConfig.[{\"DataInstanceType\":InstanceType,\"DedicatedMasterType\":DedicatedMasterType}]'"

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

# Define allowed instance types (Modify this list based on organizational policy)
ALLOWED_INSTANCES=("r5.large.elasticsearch" "m5.large.elasticsearch" "c5.large.elasticsearch")

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains
declare -A instance_mappings

# Function to check OpenSearch domain instance types
check_instance_types() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    if [[ -z "$domain_names" ]]; then
        echo "| $REGION | No domains found |"
        return
    fi

    checked_count=0
    declare -A domain_instances

    for DOMAIN in $domain_names; do
        checked_count=$((checked_count + 1))
        instance_data=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.ElasticsearchClusterConfig.[{"DataInstanceType":InstanceType,"DedicatedMasterType":DedicatedMasterType}]' --output text 2>/dev/null)

        if [[ -n "$instance_data" ]]; then
            domain_instances["$DOMAIN"]="$instance_data"
        fi
    done

    total_domains["$REGION"]=$checked_count
    instance_mappings["$REGION"]=$(declare -p domain_instances)

    printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_instance_types "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
violation_found=false

echo -e "${PURPLE}Checking OpenSearch domains for non-compliant instance types...${NC}"

for region in "${!instance_mappings[@]}"; do
    eval "declare -A domains_in_region=${instance_mappings[$region]}"
    
    found_domains=()
    for domain in "${!domains_in_region[@]}"; do
        instance_info="${domains_in_region[$domain]}"
        data_instance=$(echo "$instance_info" | awk '{print $1}')
        master_instance=$(echo "$instance_info" | awk '{print $2}')

        if [[ ! " ${ALLOWED_INSTANCES[@]} " =~ " $data_instance " || ! " ${ALLOWED_INSTANCES[@]} " =~ " $master_instance " ]]; then
            found_domains+=("$domain")
            echo -e "${RED}Region: $region${NC}"
            echo "OpenSearch Domain: $domain"
            echo "Non-Compliant Data Instance: $data_instance"
            echo "Non-Compliant Master Instance: $master_instance"
            echo "----------------------------------------------------------------"
            violation_found=true
        fi
    done
done

if [[ "$violation_found" = false ]]; then
    echo -e "${GREEN}All OpenSearch domains are using compliant instance types.${NC}"
fi

echo "Audit completed for all regions."
