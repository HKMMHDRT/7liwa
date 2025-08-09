#!/bin/bash

# Script to fix postfix configuration issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   POSTFIX CONFIG FIX${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root: sudo ./fix_postfix_config.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}Fixing postfix configuration issues...${NC}"

# Backup current config
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ Configuration backed up${NC}"

# Remove duplicate mailbox_size_limit entries
echo -e "${YELLOW}Removing duplicate mailbox_size_limit entries...${NC}"
sed -i '/^mailbox_size_limit = 0$/d' /etc/postfix/main.cf
echo "mailbox_size_limit = 0" >> /etc/postfix/main.cf
echo -e "${GREEN}✓ Fixed mailbox_size_limit duplication${NC}"

# Set compatibility level to suppress warnings
echo -e "${YELLOW}Setting compatibility level...${NC}"
postconf compatibility_level=3.6
echo -e "${GREEN}✓ Compatibility level set${NC}"

# Reload postfix configuration
echo -e "${YELLOW}Reloading postfix configuration...${NC}"
postfix reload
echo -e "${GREEN}✓ Postfix configuration reloaded${NC}"

# Test configuration
echo -e "${YELLOW}Testing postfix configuration...${NC}"
if postfix check; then
    echo -e "${GREEN}✓ Postfix configuration is valid${NC}"
else
    echo -e "${RED}✗ Postfix configuration has errors${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Postfix configuration fixed successfully!${NC}"
echo -e "${CYAN}You can now restart the services:${NC}"
echo -e "${BLUE}sudo service postfix restart${NC}"
echo -e "${BLUE}sudo service opendkim restart${NC}"