#!/bin/bash

# Description and Criteria
description="AWS Audit to check the feature set enabled for the AWS Organization."
criteria="Identifies organizations using 'CONSOLIDATED_BILLING' instead of 'ALL', which limits control over member accounts using SCPs."

# Commands used
command_used="Commands Used:
  aws organizations describe-organization --query \"Organization.FeatureSet\""

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

# Step 1: Check Organization Feature Set
feature_set=$(aws organizations describe-organization --profile "$PROFILE" --query "Organization.FeatureSet" --output text 2>&1)

# Step 2: Determine Compliance Status
echo "---------------------------------------------------------------------"
echo "Audit Results (AWS Organization Feature Set)"
echo "---------------------------------------------------------------------"

if [[ "$feature_set" == "CONSOLIDATED_BILLING" ]]; then
    echo "Non-Compliant: The AWS Organization is using 'CONSOLIDATED_BILLING' instead of 'ALL'."
    echo "Security Control Policies (SCPs) cannot be applied to member accounts."
elif [[ "$feature_set" == "ALL" ]]; then
    echo "Compliant: The AWS Organization is using 'ALL' features, allowing full control over member accounts."
else
    echo "ERROR: Unable to determine the feature set. Ensure the AWS account is part of an organization."
fi

echo "---------------------------------------------------------------------"
echo "Audit completed."
