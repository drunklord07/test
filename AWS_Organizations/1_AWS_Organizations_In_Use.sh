#!/bin/bash

# Description and Criteria
description="AWS Audit to check if the account is part of an AWS Organization."
criteria="Identifies accounts that are not part of an AWS Organization, which may indicate lack of centralized management."

# Commands used
command_used="Commands Used:
  aws organizations describe-organization"

# Display script metadata
echo ""
echo "---------------------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
echo "---------------------------------------------------------------------"
echo ""

# Set AWS CLI profile
PROFILE="my-role"

# Validate if the profile exists
if ! aws configure list-profiles | grep -q "^$PROFILE$"; then
  echo "ERROR: AWS profile '$PROFILE' does not exist."
  exit 1
fi

# Step 1: Check Organization Membership
org_info=$(aws organizations describe-organization --profile "$PROFILE" 2>&1)

# Step 2: Determine Compliance Status
echo "---------------------------------------------------------------------"
echo "Audit Results (AWS Organization Membership)"
echo "---------------------------------------------------------------------"

if echo "$org_info" | grep -q "AWSOrganizationsNotInUseException"; then
    echo "Non-Compliant: This AWS account is NOT part of an AWS Organization."
else
    echo "Compliant: This AWS account is part of an AWS Organization."
fi

echo "---------------------------------------------------------------------"
echo "Audit completed."
