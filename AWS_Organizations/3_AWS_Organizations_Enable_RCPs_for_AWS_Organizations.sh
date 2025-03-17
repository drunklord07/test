#!/bin/bash

# Description and Criteria
description="AWS Audit to check if Resource Control Policies (RCPs) are enabled for the AWS Organization."
criteria="Identifies organizations where RCPs are not enabled, which limits control over resource management."

# Commands used
command_used="Commands Used:
  aws organizations list-roots --query 'Roots[*].PolicyTypes[?Type==\`RESOURCE_CONTROL_POLICY\`].Status | []'"

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

# Step 1: Check Resource Control Policies (RCPs) Status
rcp_status=$(aws organizations list-roots --profile "$PROFILE" --query "Roots[*].PolicyTypes[?Type=='RESOURCE_CONTROL_POLICY'].Status | []" --output text 2>&1)

# Step 2: Determine Compliance Status
echo "---------------------------------------------------------------------"
echo "Audit Results (AWS Organization Resource Control Policies)"
echo "---------------------------------------------------------------------"

if [[ "$rcp_status" == "None" || -z "$rcp_status" ]]; then
    echo "Non-Compliant: Resource Control Policies (RCPs) are NOT enabled for the AWS Organization."
elif [[ "$rcp_status" == "ENABLED" ]]; then
    echo "Compliant: Resource Control Policies (RCPs) are enabled for the AWS Organization."
else
    echo "ERROR: Unable to determine the RCP status. Ensure the AWS account is part of an organization and has the necessary permissions."
fi

echo "---------------------------------------------------------------------"
echo "Audit completed."
