#!/bin/bash

# Enhanced SIBOU3AZA Setup with Authentication & Tracking
# Make sure the script is being run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo privileges."
  exit 1
fi

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA Enhanced Setup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Get current IP address
echo -e "${YELLOW}Detecting current IP address...${NC}"
CURRENT_IP=$(curl -s ifconfig.me)
echo -e "${GREEN}Current IP: $CURRENT_IP${NC}"
echo ""

# Prompt for user inputs
echo -e "${YELLOW}Please provide the following information:${NC}"
read -p "Enter your domain name (e.g., yourdomain.com): " domain_name
read -p "Enter the custom myhostname (or press Enter for $domain_name): " myhostname
myhostname=${myhostname:-$domain_name}

read -p "Enter the sender email address: " sender_email
read -p "Enter the sender name: " sender_name
read -p "Enter the email subject (for manual sending): " email_subject
read -p "Enter the path to your email list file (e.g., emaillist.txt): " email_list

echo ""
echo -e "${BLUE}Email Forwarding System Setup:${NC}"
read -p "Enter forwarding email address (e.g., forward@$domain_name): " forward_email
forward_email=${forward_email:-forward@$domain_name}

echo ""
echo -e "${BLUE}SIBOU3AZA2 - Email Forwarding Revolution Setup${NC}"
echo -e "${GREEN}No EML files required for the forwarding system!${NC}"
echo -e "${YELLOW}EML templates are only needed for traditional sending method.${NC}"
echo ""

# Update package list and install required packages
echo -e "${YELLOW}Updating package list and installing required packages...${NC}"
sudo apt-get update -y
sudo apt-get install postfix postfix-pcre opendkim opendkim-tools tmux mailutils dnsutils -y

# Create OpenDKIM directory
echo -e "${YELLOW}Setting up DKIM...${NC}"
sudo mkdir -p /etc/opendkim/keys/$domain_name

# Generate DKIM key pair
echo -e "${YELLOW}Generating DKIM keys for $domain_name...${NC}"
sudo opendkim-genkey -t -s mail -d $domain_name -D /etc/opendkim/keys/$domain_name/

# Set proper permissions
sudo chown opendkim:opendkim /etc/opendkim/keys/$domain_name/mail.private
sudo chmod 600 /etc/opendkim/keys/$domain_name/mail.private

# Backup original configs
echo -e "${YELLOW}Backing up original configuration files...${NC}"
sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.backup 2>/dev/null || true
sudo cp /etc/opendkim.conf /etc/opendkim.conf.backup 2>/dev/null || true

# Create OpenDKIM configuration
echo -e "${YELLOW}Configuring OpenDKIM...${NC}"
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

# Create TrustedHosts
sudo tee /etc/opendkim/TrustedHosts > /dev/null <<EOL
127.0.0.1
localhost
192.168.0.1/24
*.$domain_name
$CURRENT_IP
EOL

# Create KeyTable
sudo tee /etc/opendkim/KeyTable > /dev/null <<EOL
mail._domainkey.$domain_name $domain_name:mail:/etc/opendkim/keys/$domain_name/mail.private
EOL

# Create SigningTable
sudo tee /etc/opendkim/SigningTable > /dev/null <<EOL
*@$domain_name mail._domainkey.$domain_name
EOL

# Configure Postfix main.cf
echo -e "${YELLOW}Configuring Postfix...${NC}"
sudo tee /etc/postfix/main.cf > /dev/null <<EOL
# Postfix main configuration file with DKIM support

# Set the hostname
myhostname = $myhostname
mydomain = $domain_name

# Network interfaces
inet_interfaces = all
inet_protocols = ipv4

# Basic settings
myorigin = \$mydomain
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
relayhost = 
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128

# Mailbox settings
home_mailbox = Maildir/
mailbox_size_limit = 0
recipient_delimiter = +

# TLS settings
smtp_tls_security_level = may
smtpd_tls_security_level = may
smtpd_tls_auth_only = no

# DKIM integration
milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:12301
non_smtpd_milters = inet:localhost:12301

# Queue settings
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/lib/postfix/sbin
data_directory = /var/lib/postfix

# Other settings
mail_owner = postfix
default_privs = nobody
EOL

# Start services
echo -e "${YELLOW}Starting services...${NC}"
sudo systemctl restart opendkim
sudo systemctl restart postfix
sudo systemctl enable opendkim
sudo systemctl enable postfix

# Generate DNS records
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   DNS RECORDS TO ADD${NC}"
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
cat /etc/opendkim/keys/$domain_name/mail.txt | grep -v "mail._domainkey" | tr -d '\n' | tr -d '\t' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
echo ""
echo ""

# DMARC Record
echo -e "${YELLOW}3. DMARC Record:${NC}"
echo -e "${BLUE}Type: TXT${NC}"
echo -e "${BLUE}Name: _dmarc${NC}"
echo -e "${BLUE}Value: v=DMARC1; p=none; rua=mailto:dmarc@$domain_name; ruf=mailto:dmarc@$domain_name; fo=1${NC}"
echo ""

echo -e "${GREEN}================================${NC}"
echo ""

# Create verification script
echo -e "${YELLOW}Creating domain verification script...${NC}"
cat > verify_domain.sh <<'EOF'
#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN=$1
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Usage: ./verify_domain.sh yourdomain.com${NC}"
    exit 1
fi

echo -e "${BLUE}Verifying DNS records for: $DOMAIN${NC}"
echo ""

# Check SPF
echo -e "${YELLOW}Checking SPF record...${NC}"
SPF_RECORD=$(dig TXT $DOMAIN +short | grep "v=spf1")
if [ -n "$SPF_RECORD" ]; then
    echo -e "${GREEN}✓ SPF Record Found: $SPF_RECORD${NC}"
else
    echo -e "${RED}✗ SPF Record Not Found${NC}"
fi

# Check DKIM
echo -e "${YELLOW}Checking DKIM record...${NC}"
DKIM_RECORD=$(dig TXT mail._domainkey.$DOMAIN +short | grep "v=DKIM1")
if [ -n "$DKIM_RECORD" ]; then
    echo -e "${GREEN}✓ DKIM Record Found${NC}"
else
    echo -e "${RED}✗ DKIM Record Not Found${NC}"
fi

# Check DMARC
echo -e "${YELLOW}Checking DMARC record...${NC}"
DMARC_RECORD=$(dig TXT _dmarc.$DOMAIN +short | grep "v=DMARC1")
if [ -n "$DMARC_RECORD" ]; then
    echo -e "${GREEN}✓ DMARC Record Found: $DMARC_RECORD${NC}"
else
    echo -e "${RED}✗ DMARC Record Not Found${NC}"
fi

echo ""
if [ -n "$SPF_RECORD" ] && [ -n "$DKIM_RECORD" ] && [ -n "$DMARC_RECORD" ]; then
    echo -e "${GREEN}All DNS records are properly configured!${NC}"
    exit 0
else
    echo -e "${RED}Some DNS records are missing. Please add them and try again.${NC}"
    exit 1
fi
EOF

chmod +x verify_domain.sh

# Create the enhanced sending script
echo -e "${YELLOW}Creating enhanced sending script with tracking...${NC}"
cat > send.sh <<EOF
#!/bin/bash

# Enhanced Email Sender with EML Processing and Tracking
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="$domain_name"
SENDER_EMAIL="$sender_email"
SENDER_NAME="$sender_name"
SUBJECT="$email_subject"
EMAIL_LIST="$email_list"

# Initialize tracking files
echo "Email Delivery Tracking - Started: \$(date)" > successdelivery.txt
echo "Email Delivery Failures - Started: \$(date)" > faileddelivery.txt
echo "Email Campaign Statistics - Started: \$(date)" > deliverystats.txt

# Verify DNS records first
echo -e "\${BLUE}Verifying DNS records before sending...\${NC}"
if ! ./verify_domain.sh \$DOMAIN; then
    echo -e "\${RED}DNS verification failed. Please configure DNS records first.\${NC}"
    exit 1
fi

echo -e "\${GREEN}DNS records verified successfully!\${NC}"
echo ""

# Check if email.eml exists
if [ ! -f "email.eml" ]; then
    echo -e "\${RED}Error: email.eml template file not found!\${NC}"
    exit 1
fi

# Check if email list exists
if [ ! -f "\$EMAIL_LIST" ]; then
    echo -e "\${RED}Error: Email list file '\$EMAIL_LIST' not found!\${NC}"
    exit 1
fi

# Count total emails
TOTAL_EMAILS=\$(wc -l < "\$EMAIL_LIST")
CURRENT_EMAIL=0
SUCCESS_COUNT=0
FAILURE_COUNT=0

echo -e "\${BLUE}Starting email campaign...\${NC}"
echo -e "\${BLUE}Total emails to send: \$TOTAL_EMAILS\${NC}"
echo ""

# Function to process EML and send email
send_email() {
    local recipient=\$1
    local temp_file="/tmp/email_\$\$.eml"
    
    # Copy original EML and modify headers
    cp email.eml "\$temp_file"
    
    # Remove existing To, From, Subject headers and add new ones
    sed -i '/^To:/d' "\$temp_file"
    sed -i '/^From:/d' "\$temp_file"
    sed -i '/^Subject:/d' "\$temp_file"
    
    # Add new headers at the beginning
    sed -i "1i\\
To: \$recipient\\
From: \$SENDER_NAME <\$SENDER_EMAIL>\\
Subject: \$SUBJECT" "\$temp_file"
    
    # Send email using sendmail
    if /usr/sbin/sendmail -t < "\$temp_file" 2>/dev/null; then
        echo -e "\${GREEN}✓ Sent to: \$recipient\${NC}"
        echo "\$(date): \$recipient" >> successdelivery.txt
        ((SUCCESS_COUNT++))
        rm -f "\$temp_file"
        return 0
    else
        echo -e "\${RED}✗ Failed to send to: \$recipient\${NC}"
        echo "\$(date): \$recipient - Send failed" >> faileddelivery.txt
        ((FAILURE_COUNT++))
        rm -f "\$temp_file"
        return 1
    fi
}

# Main sending loop
while IFS= read -r email; do
    # Skip empty lines and comments
    [[ -z "\$email" || "\$email" =~ ^#.* ]] && continue
    
    ((CURRENT_EMAIL++))
    echo -e "\${YELLOW}[\$CURRENT_EMAIL/\$TOTAL_EMAILS] Processing: \$email\${NC}"
    
    # Validate email format
    if [[ "\$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\$ ]]; then
        send_email "\$email"
        
        # Rate limiting - pause between emails
        sleep 2
    else
        echo -e "\${RED}✗ Invalid email format: \$email\${NC}"
        echo "\$(date): \$email - Invalid format" >> faileddelivery.txt
        ((FAILURE_COUNT++))
    fi
    
    # Show progress every 10 emails
    if (( CURRENT_EMAIL % 10 == 0 )); then
        echo -e "\${BLUE}Progress: \$CURRENT_EMAIL/\$TOTAL_EMAILS (\$SUCCESS_COUNT successful, \$FAILURE_COUNT failed)\${NC}"
    fi
    
done < "\$EMAIL_LIST"

# Final statistics
echo ""
echo -e "\${GREEN}================================\${NC}"
echo -e "\${GREEN}   CAMPAIGN COMPLETED\${NC}"
echo -e "\${GREEN}================================\${NC}"
echo -e "\${BLUE}Total Processed: \$CURRENT_EMAIL\${NC}"
echo -e "\${GREEN}Successful: \$SUCCESS_COUNT\${NC}"
echo -e "\${RED}Failed: \$FAILURE_COUNT\${NC}"

# Write final statistics
cat >> deliverystats.txt <<STATS

Campaign Completed: \$(date)
Total Processed: \$CURRENT_EMAIL
Successful Deliveries: \$SUCCESS_COUNT
Failed Deliveries: \$FAILURE_COUNT
Success Rate: \$(( SUCCESS_COUNT * 100 / CURRENT_EMAIL ))%
Domain: \$DOMAIN
Sender: \$SENDER_EMAIL
Subject: \$SUBJECT
STATS

echo ""
echo -e "\${YELLOW}Tracking files created:\${NC}"
echo -e "\${BLUE}• successdelivery.txt - Successfully delivered emails\${NC}"
echo -e "\${BLUE}• faileddelivery.txt - Failed delivery attempts\${NC}"
echo -e "\${BLUE}• deliverystats.txt - Campaign statistics\${NC}"
echo ""
EOF

chmod +x send.sh

# Create configuration file for other scripts
echo -e "${YELLOW}Creating configuration file...${NC}"
cat > sibou3aza.conf <<CONF
# SIBOU3AZA Configuration File
DOMAIN="$domain_name"
SENDER_EMAIL="$sender_email"
SENDER_NAME="$sender_name"
EMAIL_SUBJECT="$email_subject"
EMAIL_LIST="$email_list"
FORWARD_EMAIL="$forward_email"
CURRENT_IP="$CURRENT_IP"
MYHOSTNAME="$myhostname"
CONF

# Make scripts executable
echo -e "${YELLOW}Setting up forwarding system...${NC}"
chmod +x mail_processor.sh
chmod +x auto_forwarder.sh

# Configure Postfix for mail reception
echo -e "${YELLOW}Configuring mail reception...${NC}"

# Update Postfix to handle virtual domains
sudo tee -a /etc/postfix/main.cf > /dev/null <<POSTFIX_CONFIG

# Virtual domain configuration for forwarding
virtual_alias_domains = $domain_name
virtual_alias_maps = hash:/etc/postfix/virtual
virtual_mailbox_domains = $domain_name
virtual_mailbox_base = /var/mail/vhosts
virtual_mailbox_maps = hash:/etc/postfix/vmailbox
virtual_minimum_uid = 100
virtual_uid_maps = static:5000
virtual_gid_maps = static:5000

# Additional settings for forwarding
message_size_limit = 10240000
mailbox_size_limit = 1024000000
POSTFIX_CONFIG

# Create virtual user and mailbox setup
sudo mkdir -p /var/mail/vhosts/$domain_name
sudo groupadd -g 5000 vmail 2>/dev/null || true
sudo useradd -g vmail -u 5000 vmail -d /var/mail/vhosts -s /bin/false 2>/dev/null || true
sudo chown -R vmail:vmail /var/mail/vhosts

# Setup virtual mailbox and alias files
forward_user=$(echo $forward_email | cut -d@ -f1)
echo "$forward_email $domain_name/$forward_user/" | sudo tee /etc/postfix/vmailbox > /dev/null
echo "$forward_email $forward_user@localhost" | sudo tee /etc/postfix/virtual > /dev/null

# Create hash maps
sudo postmap /etc/postfix/vmailbox
sudo postmap /etc/postfix/virtual

# Restart Postfix
sudo systemctl restart postfix

# Create startup script for forwarding system
echo -e "${YELLOW}Creating forwarding system startup script...${NC}"
cat > start_forwarding.sh <<'STARTUP'
#!/bin/bash

# SIBOU3AZA Forwarding System Startup Script
echo "Starting SIBOU3AZA Forwarding System..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup mail processor
echo -e "${BLUE}Setting up mail processor...${NC}"
./mail_processor.sh setup

# Start monitoring in the background
echo -e "${BLUE}Starting mail monitoring...${NC}"
nohup ./mail_processor.sh monitor > mail_processor.log 2>&1 &
PROCESSOR_PID=$!

echo -e "${GREEN}✓ SIBOU3AZA Forwarding System started!${NC}"
echo -e "${BLUE}Mail Processor PID: $PROCESSOR_PID${NC}"
echo -e "${BLUE}Log file: mail_processor.log${NC}"
echo ""
echo -e "${BLUE}To stop the system:${NC}"
echo "kill $PROCESSOR_PID"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo "1. Send an email to: $FORWARD_EMAIL"
echo "2. Your email will be automatically forwarded to your mailing list"
echo "3. Special commands:"
echo "   - Subject: 'SEND-NOW' - Immediate forwarding"
echo "   - Subject: 'STATUS' - Get system status"
echo "   - Subject: 'ADD-SUBSCRIBER email@domain.com' - Add subscriber"
STARTUP

chmod +x start_forwarding.sh

# Final instructions
echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   SETUP COMPLETED!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "${BLUE}1. Add the DNS records shown above to your domain${NC}"
echo -e "${BLUE}2. Wait 5-10 minutes for DNS propagation${NC}"
echo -e "${BLUE}3. Verify DNS records: ./verify_domain.sh $domain_name${NC}"
echo -e "${BLUE}4. Create your email list file: $email_list${NC}"
echo -e "${BLUE}5. Start the forwarding system: ./start_forwarding.sh${NC}"
echo ""
echo -e "${YELLOW}Two ways to send emails:${NC}"
echo -e "${GREEN}Method 1 - Traditional (with .eml file):${NC}"
echo -e "${BLUE}• Place email.eml template in this directory${NC}"
echo -e "${BLUE}• Run: ./send.sh${NC}"
echo ""
echo -e "${GREEN}Method 2 - Email Forwarding (NEW!):${NC}"
echo -e "${BLUE}• Start forwarding system: ./start_forwarding.sh${NC}"
echo -e "${BLUE}• Send email to: $forward_email${NC}"
echo -e "${BLUE}• Email automatically forwards to your entire list!${NC}"
echo ""
echo -e "${YELLOW}Features included:${NC}"
echo -e "${GREEN}✓ SPF, DKIM, DMARC authentication${NC}"
echo -e "${GREEN}✓ EML template processing${NC}"
echo -e "${GREEN}✓ EMAIL FORWARDING SYSTEM (NEW!)${NC}"
echo -e "${GREEN}✓ Delivery tracking and statistics${NC}"
echo -e "${GREEN}✓ DNS verification${NC}"
echo -e "${GREEN}✓ Professional email headers${NC}"
echo -e "${GREEN}✓ Command email processing${NC}"
echo ""
