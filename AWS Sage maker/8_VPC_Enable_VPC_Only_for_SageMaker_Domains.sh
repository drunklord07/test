#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Domain Network Access"
criteria="This script checks if SageMaker domains allow public internet access."

# Commands used
command_used="Commands Used:
  1. aws sagemaker list-domains --region \$REGION --query 'Domains[*].DomainId' --output text
  2. aws sagemaker describe-domain --region \$REGION --domain-id \$DOMAIN_ID --query 'AppNetworkAccessType' --output text"

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
echo "\n+----------------+----------------+"
echo "| Region         | Domain Count   |"
echo "+----------------+----------------+"

declare -A domain_counts

# Gather SageMaker domain counts per region
for REGION in $regions; do
  domains=$(aws sagemaker list-domains --region "$REGION" --profile "$PROFILE" \
    --query 'Domains[*].DomainId' --output text)

  domain_count=$(echo "$domains" | wc -w)
  domain_counts[$REGION]=$domain_count

  printf "| %-14s | %-14s |\n" "$REGION" "$domain_count"
done

echo "+----------------+----------------+"
echo ""

# Start audit for non-compliant SageMaker domains
non_compliant_found=false

for REGION in "${!domain_counts[@]}"; do
  if [ "${domain_counts[$REGION]}" -gt 0 ]; then
    domains=$(aws sagemaker list-domains --region "$REGION" --profile "$PROFILE" \
      --query 'Domains[*].DomainId' --output text)

    for DOMAIN_ID in $domains; do
      access_type=$(aws sagemaker describe-domain --region "$REGION" --profile "$PROFILE" \
        --domain-id "$DOMAIN_ID" --query 'AppNetworkAccessType' --output text)

      if [ "$access_type" == "PublicInternetOnly" ]; then
        if [ "$non_compliant_found" = false ]; then
          echo -e "${PURPLE}Starting audit for non-compliant SageMaker domains...${NC}"
          non_compliant_found=true
        fi

        echo "--------------------------------------------------"
        echo "Region: $REGION"
        echo "Domain ID: $DOMAIN_ID"
        echo "Network Access Type: $access_type"
        echo "Status: ${RED}Non-Compliant (Public Internet Access Enabled)${NC}"
        echo "--------------------------------------------------"
      fi
    done
  fi
done

if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker domains have restricted network access.${NC}"
fi

echo "Audit completed for all regions."
