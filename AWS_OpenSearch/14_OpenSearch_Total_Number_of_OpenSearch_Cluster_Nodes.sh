#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Cluster Nodes Limit Compliance"
criteria="Checks if the total number of OpenSearch cluster nodes (data + dedicated master nodes) in an AWS account exceeds the threshold of 50."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region \$REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region \$REGION --domain-name \$DOMAIN --query 'DomainStatus.ElasticsearchClusterConfig.[{\"DataNodeCount\":InstanceCount,\"DedicatedMasterNodeCount\":DedicatedMasterCount}]'"

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

# Node count threshold
NODE_LIMIT=50

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains
declare -A node_mappings

# Function to check OpenSearch node counts
check_opensearch_nodes() {
    REGION=$1
    domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text 2>/dev/null)

    total_count=0
    declare -A non_compliant_domains_list

    if [[ -n "$domain_names" ]]; then
        for DOMAIN in $domain_names; do
            total_count=$((total_count + 1))
            node_info=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.ElasticsearchClusterConfig.[{"DataNodeCount":InstanceCount,"DedicatedMasterNodeCount":DedicatedMasterCount}]' --output json 2>/dev/null)

            data_nodes=$(echo "$node_info" | jq -r '.[0].DataNodeCount')
            master_nodes=$(echo "$node_info" | jq -r '.[0].DedicatedMasterNodeCount')

            total_nodes=$((data_nodes + master_nodes))

            if [[ "$total_nodes" -gt "$NODE_LIMIT" ]]; then
                non_compliant_domains_list["$DOMAIN"]="NON-COMPLIANT (Total Nodes: $total_nodes, Limit: $NODE_LIMIT)"
            fi
        done
    fi

    total_domains["$REGION"]=$total_count
    node_mappings["$REGION"]=$(declare -p non_compliant_domains_list)

    printf "| %-14s | %-16s |\n" "$REGION" "$total_count"
}

# Audit each region in parallel
for REGION in $regions; do
    check_opensearch_nodes "$REGION" &
done

wait

echo "+--------------+------------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing OpenSearch clusters exceeding the node limit...${NC}"

non_compliant_found=false

for region in "${!node_mappings[@]}"; do
    eval "declare -A domains_in_region=${node_mappings[$region]}"
    
    for domain in "${!domains_in_region[@]}"; do
        non_compliant_found=true
        echo -e "${RED}Region: $region${NC}"
        echo -e "${RED}OpenSearch Domain: $domain${NC}"
        echo -e "${RED}Status: ${domains_in_region[$domain]}${NC}"
        echo "----------------------------------------------------------------"
    done
done

if [[ "$non_compliant_found" == false ]]; then
    echo -e "${GREEN}All OpenSearch clusters comply with the node limit.${NC}"
fi

echo "Audit completed for all regions."
