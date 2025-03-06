#!/bin/bash

# Description and Criteria
description="AWS ACM Certificate Validation Audit"
criteria="This script lists all SSL/TLS certificates managed by ACM across multiple AWS regions and checks if they are in 'PENDING_VALIDATION' status.
Certificates in 'PENDING_VALIDATION' are marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Commands Used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws acm list-certificates --region \$REGION --query 'CertificateSummaryList[*].CertificateArn'
  3. aws acm describe-certificate --region \$REGION --certificate-arn \$cert_arn --query 'Certificate.Status'"

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

# Loop through each region and count certificates
for REGION in $regions; do
  cert_count=$(aws acm list-certificates --region "$REGION" --profile "$PROFILE" --query 'length(CertificateSummaryList)' --output text)
  region_cert_count[$REGION]=$cert_count
  printf "| %-14s | %-15s |\n" "$REGION" "$cert_count"
done

echo "+----------------+-----------------+"
echo ""

# Audit only regions with certificates
for REGION in "${!region_cert_count[@]}"; do
  if [ "${region_cert_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    certs=$(aws acm list-certificates --region "$REGION" --profile "$PROFILE" --query 'CertificateSummaryList[*].[CertificateArn, DomainName]' --output text)

    while read -r cert_arn domain_name; do
      echo "--------------------------------------------------"
      echo "Certificate ARN: $cert_arn"
      echo "Domain Name: $domain_name"

      # Get certificate validation status
      cert_status=$(aws acm describe-certificate --region "$REGION" --profile "$PROFILE" --certificate-arn "$cert_arn" --query 'Certificate.Status' --output text)

      # Compliance Check
      if [ "$cert_status" == "PENDING_VALIDATION" ]; then
        echo -e "Validation Status: ${RED}Non-Compliant (PENDING_VALIDATION)${NC}"
      else
        echo -e "Validation Status: ${GREEN}Compliant${NC}"
      fi
    done <<< "$certs"

    echo "--------------------------------------------------"
  fi
done

echo "Audit completed for all regions with ACM certificates."
