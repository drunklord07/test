#!/bin/bash

# Description and Criteria
description="AWS ACM Wildcard Certificate Audit"
criteria="This script lists all SSL/TLS certificates managed by ACM across multiple AWS regions and checks if they are wildcard certificates.
Certificates that start with '*' are marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Commands Used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws acm list-certificates --region \$REGION --certificate-statuses ISSUED --query 'CertificateSummaryList[*].CertificateArn'
  3. aws acm describe-certificate --region \$REGION --certificate-arn \$cert_arn --query 'Certificate.DomainName'"

# Color Codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display Description
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

# Validate AWS Profile
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

# Table Header
echo "\n+----------------+-----------------+"
echo "| Region        | Total Certs     |"
echo "+----------------+-----------------+"

declare -A region_cert_count

# Loop through each region and count issued certificates
for REGION in $regions; do
  cert_count=$(aws acm list-certificates --region "$REGION" --profile "$PROFILE" --certificate-statuses ISSUED --query 'length(CertificateSummaryList)' --output text)
  region_cert_count[$REGION]=$cert_count
  printf "| %-14s | %-15s |\n" "$REGION" "$cert_count"
done

echo "+----------------+-----------------+"
echo ""

# Audit only regions with issued certificates
for REGION in "${!region_cert_count[@]}"; do
  if [ "${region_cert_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    certs=$(aws acm list-certificates --region "$REGION" --profile "$PROFILE" --certificate-statuses ISSUED --query 'CertificateSummaryList[*].CertificateArn' --output text)

    while read -r cert_arn; do
      echo "--------------------------------------------------"
      echo "Certificate ARN: $cert_arn"

      # Get domain name for the certificate
      domain_name=$(aws acm describe-certificate --region "$REGION" --profile "$PROFILE" --certificate-arn "$cert_arn" --query 'Certificate.DomainName' --output text)

      echo "Domain Name: $domain_name"

      # Compliance Check
      if [[ "$domain_name" == \** ]]; then
        echo -e "Wildcard Status: ${RED}Non-Compliant (Wildcard Certificate)${NC}"
      else
        echo -e "Wildcard Status: ${GREEN}Compliant${NC}"
      fi
    done <<< "$certs"

    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with issued ACM certificates."
