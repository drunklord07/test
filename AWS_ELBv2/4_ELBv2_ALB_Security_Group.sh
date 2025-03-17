#!/bin/bash

# Description and Criteria
description="AWS Audit for ALB Security Groups & Listener Configurations"
criteria="This script checks ALBs for insecure security group settings and ensures listener configurations match expected security rules."

# Commands used
command_used="Commands Used:
  1. aws ec2 describe-regions --query 'Regions[*].RegionName' --output text
  2. aws elbv2 describe-load-balancers --region \$REGION --query 'LoadBalancers[?(Type == \`application\`)].LoadBalancerArn' --output text
  3. aws elbv2 describe-listeners --region \$REGION --load-balancer-arn \$ALB_ARN --query 'Listeners[*].[Protocol,Port]' --output text
  4. aws elbv2 describe-load-balancers --region \$REGION --load-balancer-arns \$ALB_ARN --query 'LoadBalancers[*].SecurityGroups[]' --output text
  5. aws ec2 describe-security-groups --region \$REGION --group-ids \$SG_ID --query 'SecurityGroups[*]' --output json"

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
echo "Region         | Total ALBs "
echo "+--------------+-----------+"

declare -A total_albs
declare -A non_compliant_albs

# Audit each region
for REGION in $regions; do
  # Get all ALB ARNs
  alb_arns=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
    --query 'LoadBalancers[?(Type == `application`)].LoadBalancerArn' --output text)

  alb_count=0
  non_compliant_list=()

  for ALB_ARN in $alb_arns; do
    ((alb_count++))

    # Get listener protocols and ports
    LISTENER_INFO=$(aws elbv2 describe-listeners --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arn "$ALB_ARN" \
      --query 'Listeners[*].[Protocol,Port]' --output text)

    # Extract protocol and port
    LISTENER_PROTOCOL=$(echo "$LISTENER_INFO" | awk '{print $1}')
    LISTENER_PORT=$(echo "$LISTENER_INFO" | awk '{print $2}')

    # Get associated security groups
    SG_IDS=$(aws elbv2 describe-load-balancers --region "$REGION" --profile "$PROFILE" \
      --load-balancer-arns "$ALB_ARN" --query 'LoadBalancers[*].SecurityGroups[]' --output text)

    for SG_ID in $SG_IDS; do
      # Get security group details
      SG_DETAILS=$(aws ec2 describe-security-groups --region "$REGION" --profile "$PROFILE" \
        --group-ids "$SG_ID" --query 'SecurityGroups[*]' --output json)

      # Check for default security group
      if echo "$SG_DETAILS" | grep -q '"GroupName": "default"'; then
        non_compliant_list+=("$ALB_ARN (Default Security Group: $SG_ID)")
        continue
      fi

      # Check inbound rules against listener config
      INBOUND_RULES=$(echo "$SG_DETAILS" | jq -r '.[] | .IpPermissions[] | select(.IpProtocol=="-1" or (.IpProtocol=="tcp" and .FromPort=='"$LISTENER_PORT"'))')
      if [[ -z "$INBOUND_RULES" ]]; then
        non_compliant_list+=("$ALB_ARN (Security Group $SG_ID has mismatched inbound rules)")
      fi
    done
  done

  total_albs["$REGION"]=$alb_count
  non_compliant_albs["$REGION"]="${non_compliant_list[*]}"

  printf "| %-14s | %-9s |\n" "$REGION" "$alb_count"
done

echo "+--------------+-----------+"
echo ""

# Audit Section
if [ ${#non_compliant_albs[@]} -gt 0 ]; then
  echo -e "${RED}Non-Compliant ALBs:${NC}"
  echo "----------------------------------------------------------------"

  for region in "${!non_compliant_albs[@]}"; do
    if [[ -n "${non_compliant_albs[$region]}" ]]; then
      echo -e "${PURPLE}Region: $region${NC}"
      echo "Non-Compliant ALBs:"
      echo -e "${non_compliant_albs[$region]}" | awk '{print " - " $0}'
      echo "----------------------------------------------------------------"
    fi
  done
else
  echo -e "${GREEN}All ALBs have secure security group settings and listener configurations.${NC}"
fi

echo "Audit completed for all regions."
