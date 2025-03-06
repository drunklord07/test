#!/bin/bash

# Description and Criteria
description="AWS ACM Expired Certificates Audit"
criteria="This script lists all AWS ACM certificates across multiple AWS regions and checks if they are expired.
If a certificate is expired, it is marked as 'Non-Compliant' (printed in red), otherwise 'Compliant' (printed in green)."

# Command being used to fetch the data
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws acm list-certificates --region \$REGION --query 'CertificateSummaryList[*].CertificateArn'
  3. aws acm describe-certificate --region \$REGION --certificate-arn \$cert_arn --query 'Certificate.Status'"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'  # No color

# Display description, criteria, and the command being used
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
echo "\n+----------------+-----------------+"
echo "| Region        | Total Certs     |"
echo "+----------------+-----------------+"

# Loop through each region and count ACM certificates
declare -A region_cert_count
for REGION in $regions; do
  cert_count=$(aws acm list-certificates --region "$REGION" --profile "$PROFILE" --query 'length(CertificateSummaryList)' --output text)
  region_cert_count[$REGION]=$cert_count
  printf "| %-14s | %-15s |\n" "$REGION" "$cert_count"
done
echo "+----------------+-----------------+"
echo ""

# Audit only regions with ACM certificates
for REGION in "${!region_cert_count[@]}"; do
  if [ "${region_cert_count[$REGION]}" -gt 0 ]; then
    echo -e "${PURPLE}Starting audit for region: $REGION${NC}"

    certs=$(aws acm list-certificates --region "$REGION" --profile "$PROFILE" --query 'CertificateSummaryList[*].[CertificateArn,DomainName]' --output text)
    while read -r cert_arn domain_name; do
      status=$(aws acm describe-certificate --region "$REGION" --profile "$PROFILE" --certificate-arn "$cert_arn" --query 'Certificate.Status' --output text)
      echo "--------------------------------------------------"
      echo "Certificate ARN: $cert_arn"
      echo "Domain Name: $domain_name"
      if [ "$status" == "EXPIRED" ]; then
        echo -e "Status: ${RED} Non-Compliant (Expired)${NC}"
      else
        echo -e "Status: ${GREEN} Compliant (Active)${NC}"
      fi
    done <<< "$certs"
    echo "--------------------------------------------------"
  fi
done
echo "Audit completed for all regions with AWS ACM certificates."
