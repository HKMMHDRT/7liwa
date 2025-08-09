#!/bin/bash

# SIBOU3AZA4 - System Restoration Script
# Restores deleted files and configurations for bulk email sending

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}   SIBOU3AZA4 SYSTEM RESTORE${NC}"
echo -e "${PURPLE}   Fixing Deleted Files${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

# Function to check and restore system components
check_system_status() {
    echo -e "${CYAN}🔍 Checking system status...${NC}"
    echo ""
    
    # Check Postfix
    echo -e "${YELLOW}1. Checking Postfix service...${NC}"
    if systemctl is-active --quiet postfix 2>/dev/null; then
        echo -e "${GREEN}✓ Postfix is running${NC}"
    else
        echo -e "${RED}✗ Postfix not running or not installed${NC}"
        NEEDS_POSTFIX=true
    fi
    
    # Check OpenDKIM
    echo -e "${YELLOW}2. Checking OpenDKIM service...${NC}"
    if systemctl is-active --quiet opendkim 2>/dev/null; then
        echo -e "${GREEN}✓ OpenDKIM is running${NC}"
    else
        echo -e "${RED}✗ OpenDKIM not running or not installed${NC}"
        NEEDS_OPENDKIM=true
    fi
    
    # Check DKIM keys
    echo -e "${YELLOW}3. Checking DKIM keys...${NC}"
    if [ -d "/etc/opendkim/keys" ] && [ "$(ls -A /etc/opendkim/keys 2>/dev/null)" ]; then
        echo -e "${GREEN}✓ DKIM keys directory exists and has content${NC}"
    else
        echo -e "${RED}✗ DKIM keys missing or empty${NC}"
        NEEDS_DKIM_KEYS=true
    fi
    
    # Check Postfix config
    echo -e "${YELLOW}4. Checking Postfix configuration...${NC}"
    if [ -f "/etc/postfix/main.cf" ] && grep -q "milter_default_action" /etc/postfix/main.cf; then
        echo -e "${GREEN}✓ Postfix configured with DKIM support${NC}"
    else
        echo -e "${RED}✗ Postfix missing DKIM configuration${NC}"
        NEEDS_POSTFIX_CONFIG=true
    fi
    
    echo ""
}

# Function to get domain information
get_domain_config() {
    echo -e "${YELLOW}=== DOMAIN CONFIGURATION ===${NC}"
    echo ""
    
    # Check if we have a working domain from previous runs
    if [ -f "last_working_domain.txt" ]; then
        LAST_DOMAIN=$(cat last_working_domain.txt)
        echo -e "${BLUE}Found previous working domain: $LAST_DOMAIN${NC}"
        read -p "Use this domain again? (y/n): " use_last
        if [[ "$use_last" =~ ^[Yy]$ ]]; then
            DOMAIN="$LAST_DOMAIN"
        fi
    fi
    
    # If no domain set, prompt for it
    if [ -z "$DOMAIN" ]; then
        read -p "Enter your domain name (e.g., 2canrescue.org): " DOMAIN
        if [ -z "$DOMAIN" ]; then
            echo -e "${RED}Domain name is required!${NC}"
            exit 1
        fi
    fi
    
    # Save this as working domain
    echo "$DOMAIN" > last_working_domain.txt
    
    # Get current IP
    echo -e "${YELLOW}Getting current IP address...${NC}"
    CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
    echo -e "${BLUE}Current IP: $CURRENT_IP${NC}"
    
    # Set sender email
    read -p "Enter sender email (default: noreply@$DOMAIN): " SENDER_EMAIL
    SENDER_EMAIL=${SENDER_EMAIL:-"noreply@$DOMAIN"}
    
    echo ""
    echo -e "${GREEN}Domain Configuration:${NC}"
    echo -e "${BLUE}Domain: $DOMAIN${NC}"
    echo -e "${BLUE}IP: $CURRENT_IP${NC}"
    echo -e "${BLUE}Sender: $SENDER_EMAIL${NC}"
    echo ""
}

# Function to restore Postfix and OpenDKIM
restore_mail_system() {
    echo -e "${CYAN}🔧 Restoring mail system...${NC}"
    echo ""
    
    if [ "$NEEDS_POSTFIX" = true ] || [ "$NEEDS_OPENDKIM" = true ]; then
        echo -e "${YELLOW}Installing missing packages...${NC}"
        sudo apt-get update -y
        sudo apt-get install postfix postfix-pcre opendkim opendkim-tools mailutils dnsutils -y
    fi
    
    # Restore OpenDKIM configuration
    echo -e "${YELLOW}Restoring OpenDKIM configuration...${NC}"
    sudo mkdir -p /etc/opendkim/keys/$DOMAIN
    
    # Generate new DKIM keys if missing
    if [ "$NEEDS_DKIM_KEYS" = true ]; then
        echo -e "${YELLOW}Generating new DKIM keys...${NC}"
        sudo opendkim-genkey -t -s mail -d $DOMAIN -D /etc/opendkim/keys/$DOMAIN/
        sudo chown opendkim:opendkim /etc/opendkim/keys/$DOMAIN/mail.private
        sudo chmod 600 /etc/opendkim/keys/$DOMAIN/mail.private
    fi
    
    # Restore OpenDKIM config
    sudo tee /etc/opendkim.conf > /dev/null <<EOL
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
EOL

    # Restore supporting files
    sudo tee /etc/opendkim/TrustedHosts > /dev/null <<EOL
127.0.0.1
localhost
192.168.0.1/24
*.$DOMAIN
$CURRENT_IP
EOL

    sudo tee /etc/opendkim/KeyTable > /dev/null <<EOL
mail._domainkey.$DOMAIN $DOMAIN:mail:/etc/opendkim/keys/$DOMAIN/mail.private
EOL

    sudo tee /etc/opendkim/SigningTable > /dev/null <<EOL
*@$DOMAIN mail._domainkey.$DOMAIN
EOL

    # Restore Postfix configuration
    echo -e "${YELLOW}Restoring Postfix configuration...${NC}"
    sudo tee /etc/postfix/main.cf > /dev/null <<EOL
# SIBOU3AZA4 Postfix Configuration
myhostname = $DOMAIN
mydomain = $DOMAIN

inet_interfaces = all
inet_protocols = ipv4

myorigin = \$mydomain
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

home_mailbox = Maildir/
mailbox_size_limit = 0
recipient_delimiter = +

smtp_tls_security_level = may
smtpd_tls_security_level = may
smtpd_tls_auth_only = no

# DKIM integration
milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# High-volume settings
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/lib/postfix/sbin
data_directory = /var/lib/postfix
mail_owner = postfix
default_privs = nobody

# Performance optimization for bulk sending
smtp_destination_concurrency_limit = 20
smtp_destination_rate_delay = 1s
smtp_extra_recipient_limit = 100
EOL

    # Start services
    echo -e "${YELLOW}Starting mail services...${NC}"
    sudo systemctl restart opendkim
    sudo systemctl restart postfix
    sudo systemctl enable opendkim
    sudo systemctl enable postfix
    
    echo -e "${GREEN}✓ Mail system restored${NC}"
    echo ""
}

# Function to create configuration file
create_config() {
    echo -e "${YELLOW}Creating SIBOU3AZA4 configuration...${NC}"
    
    cat > sibou3aza.conf <<CONF
# SIBOU3AZA4 Configuration File
DOMAIN="$DOMAIN"
SENDER_EMAIL="$SENDER_EMAIL"
SENDER_NAME="Newsletter Team"
EMAIL_SUBJECT="Newsletter Update"
EMAIL_LIST="emaillist.txt"
CURRENT_IP="$CURRENT_IP"
MYHOSTNAME="$DOMAIN"

# Bulk Email Settings - Optimized for millions
BATCH_SIZE=2000
BATCH_DELAY=1
WORKER_COUNT=6
MAX_RETRIES=3
PROGRESS_CHECKPOINT=5000

# System restored on: $(date)
SYSTEM_RESTORED=true
RESTORE_DATE="$(date)"
CONF

    echo -e "${GREEN}✓ Configuration file created${NC}"
}

# Function to show DNS records
show_dns_records() {
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}   DNS RECORDS TO VERIFY${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    
    # SPF Record
    echo -e "${YELLOW}1. SPF Record:${NC}"
    echo -e "${BLUE}Type: TXT${NC}"
    echo -e "${BLUE}Name: @ (or your domain)${NC}"
    echo -e "${BLUE}Value: v=spf1 ip4:$CURRENT_IP include:_spf.google.com ~all${NC}"
    echo ""
    
    # DKIM Record
    echo -e "${YELLOW}2. DKIM Record:${NC}"
    echo -e "${BLUE}Type: TXT${NC}"
    echo -e "${BLUE}Name: mail._domainkey${NC}"
    echo -e "${BLUE}Value:${NC}"
    if [ -f "/etc/opendkim/keys/$DOMAIN/mail.txt" ]; then
        cat /etc/opendkim/keys/$DOMAIN/mail.txt | grep -v "mail._domainkey" | tr -d '\n' | tr -d '\t' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
    else
        echo -e "${RED}DKIM key file not found. Run DNS verification after restoration.${NC}"
    fi
    echo ""
    echo ""
    
    # DMARC Record
    echo -e "${YELLOW}3. DMARC Record:${NC}"
    echo -e "${BLUE}Type: TXT${NC}"
    echo -e "${BLUE}Name: _dmarc${NC}"
    echo -e "${BLUE}Value: v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN; ruf=mailto:dmarc@$DOMAIN; fo=1${NC}"
    echo ""
}

# Function to test the system
test_system() {
    echo -e "${CYAN}🧪 Testing restored system...${NC}"
    echo ""
    
    # Test mail services
    echo -e "${YELLOW}Testing mail services...${NC}"
    if systemctl is-active --quiet postfix && systemctl is-active --quiet opendkim; then
        echo -e "${GREEN}✓ Mail services are running${NC}"
    else
        echo -e "${RED}✗ Mail services have issues${NC}"
        return 1
    fi
    
    # Test DNS verification
    echo -e "${YELLOW}Testing DNS verification...${NC}"
    if ./verify_domain.sh "$DOMAIN"; then
        echo -e "${GREEN}✓ DNS records verified${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS records may need time to propagate${NC}"
    fi
    
    # Test sendmail
    echo -e "${YELLOW}Testing sendmail functionality...${NC}"
    if command -v sendmail >/dev/null; then
        echo -e "${GREEN}✓ Sendmail is available${NC}"
    else
        echo -e "${RED}✗ Sendmail not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ System tests completed${NC}"
    echo ""
}

# Main restoration process
main() {
    echo -e "${BLUE}SIBOU3AZA4 will restore your bulk email system${NC}"
    echo -e "${BLUE}This fixes issues caused by deleted files${NC}"
    echo ""
    
    # Check current status
    check_system_status
    
    # Get domain configuration
    get_domain_config
    
    # Ask for confirmation
    echo -e "${YELLOW}Ready to restore the system. Continue? (y/n):${NC}"
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Restoration cancelled.${NC}"
        exit 0
    fi
    
    # Restore system
    restore_mail_system
    
    # Create configuration
    create_config
    
    # Show DNS records
    show_dns_records
    
    # Test system
    test_system
    
    # Final instructions
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}   SIBOU3AZA4 RESTORATION COMPLETE${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "${BLUE}1. Verify DNS records are still configured (shown above)${NC}"
    echo -e "${BLUE}2. Test with: ./send_bulk_email.sh template.html${NC}"
    echo -e "${BLUE}3. Monitor logs: sudo tail -f /var/log/mail.log${NC}"
    echo ""
    echo -e "${GREEN}Your system should now work like before!${NC}"
    echo -e "${GREEN}Ready for high-volume bulk sending (millions of emails)${NC}"
    echo ""
}

# Run main function
main "$@"
