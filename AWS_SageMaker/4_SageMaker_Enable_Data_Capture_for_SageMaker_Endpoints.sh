#!/bin/bash

# Description and Criteria
description="AWS Audit for SageMaker Endpoints Without Data Capture Enabled"
criteria="This script identifies Amazon SageMaker endpoints that do not have Data Capture enabled in each AWS region.
Endpoints without Data Capture enabled are marked as 'Non-Compliant' (printed in red) as they may lack crucial monitoring capabilities."

# Commands being used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws sagemaker list-endpoints --region \$REGION --query 'Endpoints[*].EndpointName'
  3. aws sagemaker describe-endpoint --region \$REGION --endpoint-name \$ENDPOINT --query 'EndpointConfigName'
  4. aws sagemaker describe-endpoint-config --region \$REGION --endpoint-config-name \$ENDPOINT_CONFIG --query 'DataCaptureConfig'"

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

# Set AWS CLI profile (change this as needed)
PROFILE="my-role"

# Validate if the AWS profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Get list of all AWS regions
regions=$(aws ec2 describe-regions --query 'Regions[*].RegionName' --output text --profile "$PROFILE")

non_compliant_found=false

# Iterate through each region
for REGION in $regions; do
  endpoints=$(aws sagemaker list-endpoints --region "$REGION" --profile "$PROFILE" \
    --query 'Endpoints[*].EndpointName' --output text)

  for ENDPOINT in $endpoints; do
    endpoint_config=$(aws sagemaker describe-endpoint --region "$REGION" --profile "$PROFILE" \
      --endpoint-name "$ENDPOINT" --query 'EndpointConfigName' --output text)

    data_capture_config=$(aws sagemaker describe-endpoint-config --region "$REGION" --profile "$PROFILE" \
      --endpoint-config-name "$endpoint_config" --query 'DataCaptureConfig' --output text)

    if [[ "$data_capture_config" == "None" ]]; then
      non_compliant_found=true
      echo "--------------------------------------------------"
      echo "Region: $REGION"
      echo "Endpoint Name: $ENDPOINT"
      echo "Endpoint Config: $endpoint_config"
      echo -e "Status: ${RED}Non-Compliant (Data Capture Not Enabled)${NC}"
      echo "--------------------------------------------------"
    fi
  done
done

# Message if all endpoints are compliant
if [ "$non_compliant_found" = false ]; then
  echo -e "${GREEN}All SageMaker endpoints are compliant. Data Capture is enabled.${NC}"
fi

echo "Audit completed for all regions."
