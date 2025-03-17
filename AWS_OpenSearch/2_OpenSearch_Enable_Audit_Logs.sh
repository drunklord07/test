#!/bin/bash

# Description and Criteria
description="AWS Audit for OpenSearch Audit Logs Configuration"
criteria="This script checks if Amazon OpenSearch domains have Audit Logs enabled to ensure proper security monitoring."

# Commands used
command_used="Commands Used:
  1. aws es list-domain-names --region REGION --query 'DomainNames[*].DomainName'
  2. aws es describe-elasticsearch-domain --region REGION --domain-name DOMAIN --query 'DomainStatus.LogPublishingOptions.AUDIT_LOGS.Enabled'"

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

# Get list of AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "Region         | OpenSearch Domains"
echo "+--------------+------------------+"

declare -A total_domains

# Parallel execution function
check_opensearch_audit_logs() {
  REGION=$1
  domain_names=$(aws es list-domain-names --region "$REGION" --profile "$PROFILE" --query 'DomainNames[*].DomainName' --output text)

  if [[ -z "$domain_names" ]]; then
    return
  fi

  checked_count=0
  insecure_domains=()

  for DOMAIN in $domain_names; do
    checked_count=$((checked_count + 1))

    # Get OpenSearch domain audit log status
    log_status=$(aws es describe-elasticsearch-domain --region "$REGION" --profile "$PROFILE" --domain-name "$DOMAIN" --query 'DomainStatus.LogPublishingOptions.AUDIT_LOGS.Enabled' --output text 2>/dev/null)

    if [[ "$log_status" == "false" || -z "$log_status" ]]; then
      insecure_domains+=("$DOMAIN")
    fi
  done

  total_domains["$REGION"]=$checked_count

  printf "| %-14s | %-18s |\n" "$REGION" "$checked_count"

  if [[ ${#insecure_domains[@]} -gt 0 ]]; then
    echo -e "${RED}Region: $REGION${NC}"
    echo "OpenSearch Domains without Audit Logs Enabled:"
    for domain in "${insecure_domains[@]}"; do
      echo -e "${RED}- $domain${NC}"
    done
    echo "----------------------------------------------------------------"
  fi
}

# Run audit for each region in parallel
for REGION in $regions; do
  check_opensearch_audit_logs "$REGION" &
done
wait

echo "+--------------+------------------+"
echo ""

# Final validation
if [[ ${#total_domains[@]} -eq 0 ]]; then
  echo -e "${GREEN}All OpenSearch domains have Audit Logs enabled. No security risks found.${NC}"
fi

echo "Audit completed for all regions."
