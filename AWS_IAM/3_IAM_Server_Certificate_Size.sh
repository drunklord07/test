#!/bin/bash

# Description and Criteria
description="AWS Audit: IAM SSL/TLS Certificates Key Length Check"
criteria="This script retrieves all IAM-managed SSL/TLS certificates and checks if any have an insecure key length (1024-bit)."

# Commands used
command_used="Commands Used:
  1. aws iam list-server-certificates --query 'ServerCertificateMetadataList[*].ServerCertificateName' --output text
  2. aws iam get-server-certificate --server-certificate-name <CERT_NAME> --query 'ServerCertificate.CertificateBody' --output text
  3. openssl x509 -in <TEMP_FILE> -text -noout | grep 'Public-Key'"

# Color codes
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'  # No color

# Display script metadata
echo ""
echo "----------------------------------------------------------"
echo -e "${PURPLE}Description: $description${NC}"
echo ""
echo -e "${PURPLE}Criteria: $criteria${NC}"
echo ""
echo -e "${PURPLE}$command_used${NC}"
echo "----------------------------------------------------------"
echo ""

# Set AWS CLI profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo -e "${RED}ERROR: AWS profile '$PROFILE' does not exist.${NC}"
  exit 1
fi

# Get the list of IAM-managed server certificates
echo -e "${GREEN}Retrieving IAM-managed server certificates...${NC}"
CERTIFICATES=$(aws iam list-server-certificates --profile "$PROFILE" --query 'ServerCertificateMetadataList[*].ServerCertificateName' --output text)

if [ -z "$CERTIFICATES" ]; then
  echo -e "${GREEN}No IAM-managed server certificates found.${NC}"
  exit 0
fi

echo -e "${GREEN}Checking certificate key lengths...${NC}"

# Loop through each certificate and check key length
NON_COMPLIANT_CERTS=()
for CERT_NAME in $CERTIFICATES; do
  echo -e "Processing certificate: ${PURPLE}$CERT_NAME${NC}"

  # Create a temporary file
  TEMP_FILE=$(mktemp)

  # Get certificate body and save to temp file
  aws iam get-server-certificate --profile "$PROFILE" --server-certificate-name "$CERT_NAME" --query 'ServerCertificate.CertificateBody' --output text > "$TEMP_FILE"

  # Extract public key length
  KEY_LENGTH=$(openssl x509 -in "$TEMP_FILE" -text -noout | grep "Public-Key" | awk -F'[()]' '{print $2}')

  # Remove the temporary file
  rm -f "$TEMP_FILE"

  # Check compliance
  if [ "$KEY_LENGTH" -eq 1024 ]; then
    echo -e "${RED}Non-Compliant: Certificate '$CERT_NAME' has an insecure key length of $KEY_LENGTH bits.${NC}"
    NON_COMPLIANT_CERTS+=("$CERT_NAME")
  else
    echo -e "${GREEN}Compliant: Certificate '$CERT_NAME' has a secure key length of $KEY_LENGTH bits.${NC}"
  fi

  echo ""
done

# Display non-compliant certificates if found
if [ ${#NON_COMPLIANT_CERTS[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant IAM SSL/TLS Certificates (1024-bit keys):${NC}"
  for CERT in "${NON_COMPLIANT_CERTS[@]}"; do
    echo -e "${RED}- $CERT${NC}"
  done
else
  echo -e "${GREEN}All certificates are compliant.${NC}"
fi

echo ""
echo -e "${GREEN}Audit completed.${NC}"
