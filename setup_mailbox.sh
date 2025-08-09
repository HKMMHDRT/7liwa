#!/bin/bash

# SIBOU3AZA Mailbox Setup Script
# Creates receiving mailbox functionality for email forwarding to mailing list

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA MAILBOX SETUP${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root or with sudo privileges.${NC}"
    exit 1
fi

# Get domain configuration
echo -e "${YELLOW}Setting up mailbox receiving system...${NC}"
read -p "Enter your domain name (e.g., yourdomain.com): " DOMAIN
read -p "Enter mailbox name (default: inbox): " MAILBOX_NAME
MAILBOX_NAME=${MAILBOX_NAME:-inbox}
MAILBOX_EMAIL="${MAILBOX_NAME}@${DOMAIN}"

echo ""
echo -e "${BLUE}Configuring mailbox: ${MAILBOX_EMAIL}${NC}"

# Create mailbox user if not exists
echo -e "${YELLOW}Creating virtual mail user...${NC}"
groupadd -g 5000 vmail 2>/dev/null || true
useradd -g vmail -u 5000 vmail -d /var/mail/vhosts -s /bin/false 2>/dev/null || true

# Create mailbox directory structure
echo -e "${YELLOW}Creating mailbox directories...${NC}"
mkdir -p /var/mail/vhosts/${DOMAIN}/${MAILBOX_NAME}/{new,cur,tmp}
chown -R vmail:vmail /var/mail/vhosts
chmod -R 755 /var/mail/vhosts

# Create Maildir structure
mkdir -p /var/mail/vhosts/${DOMAIN}/${MAILBOX_NAME}/Maildir/{new,cur,tmp}
chown -R vmail:vmail /var/mail/vhosts/${DOMAIN}/${MAILBOX_NAME}

# Update Postfix configuration for mailbox receiving
echo -e "${YELLOW}Configuring Postfix for mailbox receiving...${NC}"

# Backup existing configuration
cp /etc/postfix/main.cf /etc/postfix/main.cf.backup.$(date +%Y%m%d_%H%M%S)

# Add mailbox configuration to main.cf
cat >> /etc/postfix/main.cf <<POSTFIX_MAILBOX

# Mailbox receiving configuration
virtual_mailbox_domains = ${DOMAIN}
virtual_mailbox_maps = hash:/etc/postfix/vmailbox
virtual_mailbox_base = /var/mail/vhosts
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000
virtual_minimum_uid = 100

# Maildir format
home_mailbox = Maildir/
mailbox_command = 

# Local delivery settings
local_recipient_maps = unix:passwd.byname \$alias_maps
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
POSTFIX_MAILBOX

# Create virtual mailbox mapping
echo -e "${YELLOW}Setting up virtual mailbox mapping...${NC}"
echo "${MAILBOX_EMAIL} ${DOMAIN}/${MAILBOX_NAME}/Maildir/" > /etc/postfix/vmailbox
postmap /etc/postfix/vmailbox

# Create alias for easier access
echo "${MAILBOX_EMAIL} ${MAILBOX_NAME}" > /etc/postfix/virtual
postmap /etc/postfix/virtual

# Create mail processing directory
echo -e "${YELLOW}Setting up mail processing directories...${NC}"
mkdir -p /opt/sibou3aza/mailbox
mkdir -p /opt/sibou3aza/logs
mkdir -p /opt/sibou3aza/processed
mkdir -p /opt/sibou3aza/temp

# Set permissions
chown -R vmail:vmail /opt/sibou3aza
chmod -R 755 /opt/sibou3aza

# Create mailbox monitoring script path
mkdir -p /usr/local/bin/sibou3aza
cp check_mailbox.sh /usr/local/bin/sibou3aza/ 2>/dev/null || echo "check_mailbox.sh will be created next"
cp process_emails.sh /usr/local/bin/sibou3aza/ 2>/dev/null || echo "process_emails.sh will be created next"

# Update configuration file
echo -e "${YELLOW}Updating configuration...${NC}"
cat >> sibou3aza.conf <<MAILBOX_CONFIG

# Mailbox Configuration
MAILBOX_EMAIL="${MAILBOX_EMAIL}"
MAILBOX_NAME="${MAILBOX_NAME}"
MAILBOX_PATH="/var/mail/vhosts/${DOMAIN}/${MAILBOX_NAME}/Maildir"
PROCESSING_DIR="/opt/sibou3aza"
MAILBOX_CONFIG

# Restart services
echo -e "${YELLOW}Restarting mail services...${NC}"
systemctl restart postfix
systemctl restart opendkim

# Test configuration
echo -e "${YELLOW}Testing Postfix configuration...${NC}"
postfix check
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Postfix configuration is valid${NC}"
else
    echo -e "${RED}✗ Postfix configuration has errors${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    cp /etc/postfix/main.cf.backup.$(date +%Y%m%d)* /etc/postfix/main.cf
    systemctl restart postfix
    exit 1
fi

# Final status
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   MAILBOX SETUP COMPLETED${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${BLUE}Mailbox created: ${MAILBOX_EMAIL}${NC}"
echo -e "${BLUE}Mailbox path: /var/mail/vhosts/${DOMAIN}/${MAILBOX_NAME}/Maildir${NC}"
echo -e "${BLUE}Processing directory: /opt/sibou3aza${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "${CYAN}1. Run: ./check_mailbox.sh (to verify mailbox is active)${NC}"
echo -e "${CYAN}2. Send a test email from your Gmail to: ${MAILBOX_EMAIL}${NC}"
echo -e "${CYAN}3. Run: ./check_mailbox.sh (to check if email was received)${NC}"
echo -e "${CYAN}4. Run: ./process_emails.sh (to process and forward emails)${NC}"
echo ""
echo -e "${GREEN}✓ Mailbox receiving system is ready!${NC}"
