#!/bin/bash

# SIBOU3AZA Mailbox Checker
# Checks for received emails in the configured mailbox

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA MAILBOX CHECKER${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Load configuration
if [ -f "sibou3aza.conf" ]; then
    source sibou3aza.conf
else
    echo -e "${RED}Configuration file not found. Please run setup_mailbox.sh first.${NC}"
    exit 1
fi

# Check if mailbox configuration exists
if [ -z "$MAILBOX_EMAIL" ] || [ -z "$MAILBOX_PATH" ]; then
    echo -e "${RED}Mailbox not configured. Please run setup_mailbox.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking mailbox: ${MAILBOX_EMAIL}${NC}"
echo -e "${YELLOW}Mailbox path: ${MAILBOX_PATH}${NC}"
echo ""

# Function to check mailbox status
check_mailbox_status() {
    echo -e "${CYAN}1. Checking mailbox directory...${NC}"
    
    if [ -d "$MAILBOX_PATH" ]; then
        echo -e "${GREEN}✓ Mailbox directory exists${NC}"
    else
        echo -e "${RED}✗ Mailbox directory not found${NC}"
        echo -e "${YELLOW}Run setup_mailbox.sh to create the mailbox${NC}"
        return 1
    fi
    
    # Check permissions
    if [ -r "$MAILBOX_PATH/new" ]; then
        echo -e "${GREEN}✓ Mailbox is readable${NC}"
    else
        echo -e "${RED}✗ Mailbox permissions issue${NC}"
        echo -e "${YELLOW}Fix with: sudo chown -R vmail:vmail ${MAILBOX_PATH}${NC}"
        return 1
    fi
    
    return 0
}

# Function to count emails
count_emails() {
    local new_count=0
    local cur_count=0
    
    if [ -d "$MAILBOX_PATH/new" ]; then
        new_count=$(find "$MAILBOX_PATH/new" -type f | wc -l)
    fi
    
    if [ -d "$MAILBOX_PATH/cur" ]; then
        cur_count=$(find "$MAILBOX_PATH/cur" -type f | wc -l)
    fi
    
    echo -e "${CYAN}2. Email count:${NC}"
    echo -e "${BLUE}   New emails: ${new_count}${NC}"
    echo -e "${BLUE}   Read emails: ${cur_count}${NC}"
    echo -e "${BLUE}   Total emails: $((new_count + cur_count))${NC}"
    
    return $((new_count + cur_count))
}

# Function to list recent emails
list_recent_emails() {
    echo -e "${CYAN}3. Recent emails:${NC}"
    
    local found_emails=false
    
    # Check new emails
    if [ -d "$MAILBOX_PATH/new" ]; then
        for email_file in "$MAILBOX_PATH/new"/*; do
            if [ -f "$email_file" ]; then
                found_emails=true
                local timestamp=$(stat -c %y "$email_file" 2>/dev/null | cut -d' ' -f1-2)
                local subject=$(grep -i "^Subject:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n')
                local from=$(grep -i "^From:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n')
                
                echo -e "${GREEN}   [NEW] ${timestamp}${NC}"
                echo -e "${BLUE}   From: ${from}${NC}"
                echo -e "${BLUE}   Subject: ${subject}${NC}"
                echo -e "${BLUE}   File: $(basename "$email_file")${NC}"
                echo ""
            fi
        done
    fi
    
    # Check current emails (last 5)
    if [ -d "$MAILBOX_PATH/cur" ]; then
        local count=0
        for email_file in $(ls -t "$MAILBOX_PATH/cur"/* 2>/dev/null | head -5); do
            if [ -f "$email_file" ]; then
                found_emails=true
                local timestamp=$(stat -c %y "$email_file" 2>/dev/null | cut -d' ' -f1-2)
                local subject=$(grep -i "^Subject:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n')
                local from=$(grep -i "^From:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n')
                
                echo -e "${YELLOW}   [READ] ${timestamp}${NC}"
                echo -e "${BLUE}   From: ${from}${NC}"
                echo -e "${BLUE}   Subject: ${subject}${NC}"
                echo -e "${BLUE}   File: $(basename "$email_file")${NC}"
                echo ""
                
                count=$((count + 1))
            fi
        done
    fi
    
    if [ "$found_emails" = false ]; then
        echo -e "${YELLOW}   No emails found in mailbox${NC}"
        echo ""
        echo -e "${CYAN}   To test email reception:${NC}"
        echo -e "${BLUE}   1. Send an email from your Gmail to: ${MAILBOX_EMAIL}${NC}"
        echo -e "${BLUE}   2. Wait 1-2 minutes for delivery${NC}"
        echo -e "${BLUE}   3. Run this script again to check${NC}"
    fi
}

# Function to check Postfix status
check_postfix_status() {
    echo -e "${CYAN}4. Checking mail services:${NC}"
    
    # Check Postfix
    if sudo service postfix status | grep -q "is running"; then
        echo -e "${GREEN}   ✓ Postfix is running${NC}"
    else
        echo -e "${RED}   ✗ Postfix is not running${NC}"
        echo -e "${YELLOW}   Fix with: sudo service postfix start${NC}"
    fi
    
    # Check OpenDKIM
    if sudo service opendkim status | grep -q "is running"; then
        echo -e "${GREEN}   ✓ OpenDKIM is running${NC}"
    else
        echo -e "${RED}   ✗ OpenDKIM is not running${NC}"
        echo -e "${YELLOW}   Fix with: sudo service opendkim start${NC}"
    fi
}

# Function to check mail logs
check_mail_logs() {
    echo -e "${CYAN}5. Recent mail log entries:${NC}"
    
    if [ -f "/var/log/mail.log" ]; then
        # Look for entries related to our domain in the last hour
        local recent_logs=$(sudo tail -100 /var/log/mail.log | grep -E "($(date '+%b %d %H'):|${DOMAIN}|${MAILBOX_EMAIL})" | tail -10)
        
        if [ -n "$recent_logs" ]; then
            echo "$recent_logs" | while read -r line; do
                if echo "$line" | grep -q "delivered"; then
                    echo -e "${GREEN}   $line${NC}"
                elif echo "$line" | grep -q "rejected\|bounced\|failed"; then
                    echo -e "${RED}   $line${NC}"
                else
                    echo -e "${BLUE}   $line${NC}"
                fi
            done
        else
            echo -e "${YELLOW}   No recent mail log entries found${NC}"
        fi
    else
        echo -e "${RED}   Mail log not accessible${NC}"
        echo -e "${YELLOW}   Try: sudo tail -f /var/log/mail.log${NC}"
    fi
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   NEXT STEPS${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    count_emails
    local email_count=$?
    
    if [ $email_count -eq 0 ]; then
        echo -e "${YELLOW}No emails received yet.${NC}"
        echo ""
        echo -e "${CYAN}To test email reception:${NC}"
        echo -e "${BLUE}1. Send a test email from your Gmail to: ${MAILBOX_EMAIL}${NC}"
        echo -e "${BLUE}2. Subject: Test Email Reception${NC}"
        echo -e "${BLUE}3. Wait 1-2 minutes for delivery${NC}"
        echo -e "${BLUE}4. Run: ./check_mailbox.sh${NC}"
        echo ""
        echo -e "${CYAN}Troubleshooting:${NC}"
        echo -e "${BLUE}• Check DNS MX record: dig MX ${DOMAIN}${NC}"
        echo -e "${BLUE}• Monitor logs: sudo tail -f /var/log/mail.log${NC}"
        echo -e "${BLUE}• Check Postfix: sudo systemctl status postfix${NC}"
    else
        echo -e "${GREEN}Found ${email_count} email(s) in mailbox!${NC}"
        echo ""
        echo -e "${CYAN}To process and forward emails:${NC}"
        echo -e "${BLUE}1. Run: ./process_emails.sh${NC}"
        echo -e "${BLUE}2. This will forward received emails to your mailing list${NC}"
        echo ""
        echo -e "${CYAN}To setup automatic processing:${NC}"
        echo -e "${BLUE}1. Run: ./monitor_mailbox.sh start${NC}"
        echo -e "${BLUE}2. This will automatically process new emails${NC}"
    fi
}

# Main execution
main() {
    if ! check_mailbox_status; then
        exit 1
    fi
    
    echo ""
    list_recent_emails
    check_postfix_status
    echo ""
    check_mail_logs
    show_next_steps
}

# Parse command line arguments
case "${1:-}" in
    "count")
        count_emails
        echo "Total emails: $?"
        ;;
    "status")
        check_mailbox_status && check_postfix_status
        ;;
    "logs")
        check_mail_logs
        ;;
    *)
        main
        ;;
esac
