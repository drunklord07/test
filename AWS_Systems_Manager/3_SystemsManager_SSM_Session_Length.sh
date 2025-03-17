#!/bin/bash

# Description and Criteria
description="AWS Audit for Active SSM Sessions"
criteria="Identifies all active SSM sessions and provides their human-readable start times."

# Commands used
command_used="Commands Used:
  1. aws ssm describe-sessions --region \$REGION --state Active --query 'Sessions[*].[StartDate, SessionId]'
  2. date -r <timestamp> (for human-readable time conversion)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
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
echo "Region         | Active Sessions"
echo "+--------------+----------------+"

# Function to check active SSM sessions
check_active_sessions() {
    REGION=$1
    sessions=$(aws ssm describe-sessions --region "$REGION" --state Active --profile "$PROFILE" --output text --query 'Sessions[*].[StartDate, SessionId]' 2>/dev/null)

    session_count=0
    session_list=()

    if [[ -n "$sessions" ]]; then
        while read -r start_time session_id; do
            if [[ -n "$start_time" && -n "$session_id" ]]; then
                session_count=$((session_count + 1))
                human_readable_time=$(date -d @"$start_time" 2>/dev/null || echo "N/A")
                session_list+=("$session_id ($human_readable_time)")
            fi
        done <<< "$sessions"
    fi

    printf "| %-14s | %-16s |\n" "$REGION" "$session_count"

    # Store session details for later audit section
    if (( session_count > 0 )); then
        echo "$REGION" >> /tmp/ssm_sessions.txt
        for session in "${session_list[@]}"; do
            echo "$session" >> /tmp/ssm_sessions.txt
        done
        echo "---" >> /tmp/ssm_sessions.txt
    fi
}

# Clear previous audit data
> /tmp/ssm_sessions.txt

# Audit each region
for REGION in $regions; do
    check_active_sessions "$REGION" &
done

wait

echo "+--------------+----------------+"
echo ""

# Audit Section
echo -e "${PURPLE}Listing Active SSM Sessions...${NC}"

if [[ -s /tmp/ssm_sessions.txt ]]; then
    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            echo "----------------------------------------------------------------"
        elif [[ "$line" =~ ^[a-z0-9-]+$ ]]; then
            echo -e "${RED}Region: $line${NC}"
        else
            echo -e "${RED}SSM Session: $line${NC}"
            echo -e "${RED}Status: ACTIVE${NC}"
        fi
    done < /tmp/ssm_sessions.txt
else
    echo -e "${GREEN}No active SSM sessions found.${NC}"
fi

echo "Audit completed for all regions."
