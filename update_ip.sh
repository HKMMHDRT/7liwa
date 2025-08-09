#!/bin/bash

# IP Update Helper for Google Cloud Shell
# This script helps users update DNS records when Cloud Shell IP changes

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA IP Update Helper${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Get current IP
echo -e "${YELLOW}Detecting current IP address...${NC}"
CURRENT_IP=$(curl -s ifconfig.me)
if [ -z "$CURRENT_IP" ]; then
    echo -e "${RED}Error: Could not detect IP address. Check internet connection.${NC}"
    exit 1
fi

echo -e "${GREEN}Current IP: $CURRENT_IP${NC}"
echo ""

# Check if this is a new session by looking for existing config
if [ ! -f "verify_domain.sh" ]; then
    echo -e "${RED}Error: This doesn't appear to be a configured SIBOU3AZA directory.${NC}"
    echo -e "${YELLOW}Please run setup_mailer.sh first.${NC}"
    exit 1
fi

# Ask for domain name
read -p "Enter your domain name: " domain_name
if [ -z "$domain_name" ]; then
    echo -e "${RED}Domain name is required!${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Checking if DNS records need updating...${NC}"

# Check current SPF record
CURRENT_SPF=$(dig TXT $domain_name +short | grep "v=spf1" | tr -d '"')
if [[ $CURRENT_SPF == *"$CURRENT_IP"* ]]; then
    echo -e "${GREEN}✓ SPF record already contains current IP${NC}"
    SPF_NEEDS_UPDATE=false
else
    echo -e "${YELLOW}⚠ SPF record needs updating${NC}"
    SPF_NEEDS_UPDATE=true
fi

echo ""
if [ "$SPF_NEEDS_UPDATE" = true ]; then
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}   UPDATED DNS RECORDS${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    
    echo -e "${YELLOW}Update your SPF record:${NC}"
    echo -e "${BLUE}Type: TXT${NC}"
    echo -e "${BLUE}Name: @ (or your domain)${NC}"
    echo -e "${BLUE}Value: v=spf1 ip4:$CURRENT_IP include:_spf.google.com ~all${NC}"
    echo ""
    
    echo -e "${YELLOW}Keep your existing DKIM and DMARC records unchanged.${NC}"
    echo ""
    
    echo -e "${GREEN}================================${NC}"
    echo ""
    
    echo -e "${YELLOW}Steps to update:${NC}"
    echo -e "${BLUE}1. Go to your domain DNS settings${NC}"
    echo -e "${BLUE}2. Find the existing SPF record (TXT record for @ or domain)${NC}"
    echo -e "${BLUE}3. Replace the IP address with: $CURRENT_IP${NC}"
    echo -e "${BLUE}4. Save the changes${NC}"
    echo -e "${BLUE}5. Wait 5-10 minutes for propagation${NC}"
    echo ""
    
    read -p "Press Enter after you've updated the DNS record..."
    echo ""
else
    echo -e "${GREEN}No DNS updates needed!${NC}"
    echo ""
fi

# Verify domain
echo -e "${YELLOW}Verifying DNS records...${NC}"
if ./verify_domain.sh $domain_name; then
    echo ""
    echo -e "${GREEN}✓ All DNS records verified successfully!${NC}"
    echo -e "${GREEN}Your system is ready for email sending.${NC}"
    echo ""
    echo -e "${YELLOW}To start a campaign:${NC}"
    echo -e "${BLUE}sudo ./send.sh${NC}"
else
    echo ""
    echo -e "${RED}✗ DNS verification failed.${NC}"
    echo -e "${YELLOW}Please check your DNS settings and try again.${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo -e "${BLUE}• DNS changes can take up to 24 hours to propagate${NC}"
    echo -e "${BLUE}• Make sure you updated the correct domain${NC}"
    echo -e "${BLUE}• Check for typos in the DNS records${NC}"
    exit 1
fi

# Show current system status
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SYSTEM STATUS${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Current IP: $CURRENT_IP${NC}"
echo -e "${GREEN}Domain: $domain_name${NC}"
echo -e "${GREEN}DNS Status: ✓ Verified${NC}"
echo -e "${GREEN}Mail System: ✓ Ready${NC}"
echo ""

# Check if email.eml exists
if [ -f "email.eml" ]; then
    echo -e "${GREEN}Email Template: ✓ Found${NC}"
else
    echo -e "${YELLOW}Email Template: ⚠ Missing (upload email.eml)${NC}"
fi

# Check if email list exists
if [ -f "emaillist.txt" ]; then
    EMAIL_COUNT=$(grep -v "^#" emaillist.txt | grep -v "^$" | wc -l)
    echo -e "${GREEN}Email List: ✓ Found ($EMAIL_COUNT emails)${NC}"
else
    echo -e "${YELLOW}Email List: ⚠ Missing (create emaillist.txt)${NC}"
fi

echo ""
echo -e "${YELLOW}Ready to send emails!${NC}"
