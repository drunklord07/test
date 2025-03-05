#!/bin/bash

# Script Metadata
description="AWS IAM Group Audit - Checks IAM groups for high-privilege policies (e.g., AdministratorAccess)."
criteria="IAM groups should not have 'AdministratorAccess' or other high-privilege policies attached unless explicitly required."

# Commands Used
command_used="Commands Used:
  1. aws iam list-groups --query 'Groups[*].GroupName' --output text
  2. aws iam list-attached-group-policies --group-name <GROUP_NAME> --query 'AttachedPolicies[*].PolicyName' --output text"

# Display Script Metadata
echo "---------------------------------------------------------------------"
echo "Description: $description"
echo ""
echo "Criteria: $criteria"
echo ""
echo "$command_used"
echo "---------------------------------------------------------------------"
echo ""

# Table Header - IAM Groups Count
echo "Region         | IAM Groups Found              "
echo "+----------------+---------------------------+"

# List of AWS regions
regions=("us-east-1" "us-west-2" "eu-central-1" "ap-southeast-1")

# Dictionary to store IAM group counts
declare -A group_count

# Iterate through AWS regions
for region in "${regions[@]}"; do
  # Get IAM groups in the region
  iam_groups=$(aws iam list-groups --query 'Groups[*].GroupName' --output text --region "$region")

  # Count IAM groups
  group_count=$(echo "$iam_groups" | wc -w)

  # If no IAM groups found in the region
  if [ -z "$iam_groups" ]; then
    printf "| %-14s | %-26s |\n" "$region" "None detected"
  else
    printf "| %-14s | %-26s |\n" "$region" "$group_count IAM group(s) found"
  fi
done

echo "+----------------+---------------------------+"
echo ""

# Audit Section - Checking IAM Groups
echo "Audit - IAM Group Compliance Check"
echo "---------------------------------------------------------------------"

# Iterate through AWS regions again for detailed compliance check
for region in "${regions[@]}"; do
  # Get IAM groups in the region
  iam_groups=$(aws iam list-groups --query 'Groups[*].GroupName' --output text --region "$region")

  # If no IAM groups found, skip to next region
  if [ -z "$iam_groups" ]; then
    continue
  fi

  echo "Region: $region"
  echo "----------------------"

  # Check each IAM group for attached policies
  for group in $iam_groups; do
    policies=$(aws iam list-attached-group-policies --group-name "$group" --query 'AttachedPolicies[*].PolicyName' --output text --region "$region")

    if [ -z "$policies" ]; then
      # Compliant IAM Group
      printf "Compliant: %-26s (No high-privilege policies attached)\n" "$group"
    else
      # Non-Compliant IAM Group
      policy_list=$(echo "$policies" | tr '\n' ',' | sed 's/,$//') # Convert policies to comma-separated list
      printf "Non-Compliant: %-26s (Policies: %s)\n" "$group" "$policy_list"
    fi
  done
  echo ""
done

echo "---------------------------------------------------------------------"
echo "Audit completed."
