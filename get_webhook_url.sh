#!/bin/bash

# Script to get the correct webhook URL for Cloudflare Worker

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}  WEBHOOK URL GENERATOR${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

# Get project ID and region
echo -e "${CYAN}Getting Google Cloud Shell information...${NC}"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
REGION=$(gcloud config get-value compute/region 2>/dev/null)

if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}⚠️  Could not get project ID automatically${NC}"
    echo -e "${CYAN}Getting from environment...${NC}"
    PROJECT_ID=$(echo $DEVSHELL_PROJECT_ID)
fi

if [ -z "$REGION" ]; then
    echo -e "${YELLOW}⚠️  Could not get region automatically, using default${NC}"
    REGION="europe-west1-c"
fi

echo -e "${BLUE}Project ID: ${PROJECT_ID}${NC}"
echo -e "${BLUE}Region: ${REGION}${NC}"

# Generate webhook URL
if [ -n "$PROJECT_ID" ]; then
    WEBHOOK_URL="https://8080-cs-${PROJECT_ID}-default.${REGION}.c.${PROJECT_ID}.cloudshell.dev/webhook/email"
    
    echo ""
    echo -e "${GREEN}✓ Generated webhook URL:${NC}"
    echo -e "${CYAN}${WEBHOOK_URL}${NC}"
    
    # Save to config file
    if [ -f "sibou3aza.conf" ]; then
        # Remove old webhook URL if exists
        sed -i '/WEBHOOK_URL=/d' sibou3aza.conf
        echo "WEBHOOK_URL=\"${WEBHOOK_URL}\"" >> sibou3aza.conf
        echo -e "${GREEN}✓ Webhook URL saved to configuration${NC}"
    fi
    
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  CLOUDFLARE WORKER UPDATE${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo -e "${YELLOW}Copy this code to your Cloudflare Worker:${NC}"
    echo ""
    echo -e "${CYAN}const webhookUrl = \"${WEBHOOK_URL}\";${NC}"
    echo ""
    echo -e "${YELLOW}Steps:${NC}"
    echo -e "${BLUE}1. Go to Cloudflare Dashboard > Workers & Pages${NC}"
    echo -e "${BLUE}2. Edit your 'gcs-email-forwarder' worker${NC}"
    echo -e "${BLUE}3. Replace the webhookUrl line with the code above${NC}"
    echo -e "${BLUE}4. Or use the complete fixed code from: cloudflare_worker_fixed.js${NC}"
    echo -e "${BLUE}5. Save and deploy${NC}"
    
else
    echo -e "${RED}✗ Could not determine project information${NC}"
    echo -e "${YELLOW}Manual steps:${NC}"
    echo -e "${BLUE}1. Click 'Web Preview' in Cloud Shell${NC}"
    echo -e "${BLUE}2. Select 'Preview on port 8080'${NC}"
    echo -e "${BLUE}3. Copy the generated URL${NC}"
    echo -e "${BLUE}4. Add '/webhook/email' to the end${NC}"
    echo -e "${BLUE}5. Use that URL in your Cloudflare Worker${NC}"
fi

echo ""
echo -e "${CYAN}To test the webhook URL:${NC}"
echo -e "${BLUE}curl -X POST \$WEBHOOK_URL -d 'test'${NC}"