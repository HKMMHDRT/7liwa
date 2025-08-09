#!/bin/bash

# Debug script for email flow issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   EMAIL FLOW DEBUG${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check webhook server logs
echo -e "${CYAN}1. Checking webhook server activity:${NC}"
if [ -f "webhook_server.log" ]; then
    echo -e "${YELLOW}Recent webhook server logs:${NC}"
    tail -20 webhook_server.log
    echo ""
else
    echo -e "${RED}No webhook_server.log found${NC}"
fi

# Check webhook activity logs
echo -e "${CYAN}2. Checking webhook activity logs:${NC}"
if [ -d "webhook_logs" ]; then
    local today=$(date +%Y-%m-%d)
    local today_log="webhook_logs/webhook_${today}.log"
    if [ -f "$today_log" ]; then
        echo -e "${YELLOW}Today's webhook activity:${NC}"
        cat "$today_log"
        echo ""
    else
        echo -e "${YELLOW}No activity logs for today${NC}"
    fi
else
    echo -e "${YELLOW}No webhook_logs directory${NC}"
fi

# Test webhook endpoint
echo -e "${CYAN}3. Testing webhook endpoint:${NC}"
echo -e "${YELLOW}Testing POST to webhook...${NC}"
curl -X POST http://localhost:8080/webhook/email \
  -H "Content-Type: application/octet-stream" \
  -H "X-Cloudflare-Email-From: test@example.com" \
  -H "X-Cloudflare-Email-To: nn@2canrescue.online" \
  -d "From: test@example.com
To: nn@2canrescue.online
Subject: Test Email

This is a test email body."

echo ""
echo ""

# Check email list
echo -e "${CYAN}4. Checking email list:${NC}"
if [ -f "emaillist.txt" ]; then
    echo -e "${YELLOW}Email list contents:${NC}"
    cat emaillist.txt
    echo ""
    local recipient_count=$(grep -v "^#" emaillist.txt | grep -v "^$" | wc -l)
    echo -e "${BLUE}Recipients found: $recipient_count${NC}"
else
    echo -e "${RED}emaillist.txt not found${NC}"
fi

# Check bulk sender
echo -e "${CYAN}5. Checking bulk sender:${NC}"
if [ -f "send_bulk_email.sh" ]; then
    echo -e "${GREEN}✓ send_bulk_email.sh exists${NC}"
else
    echo -e "${RED}✗ send_bulk_email.sh not found${NC}"
fi

# Check postfix logs
echo -e "${CYAN}6. Checking mail logs:${NC}"
if [ -f "/var/log/mail.log" ]; then
    echo -e "${YELLOW}Recent mail activity:${NC}"
    sudo tail -10 /var/log/mail.log 2>/dev/null || echo "Cannot access mail.log"
else
    echo -e "${YELLOW}No mail.log found${NC}"
fi

echo ""
echo -e "${CYAN}7. System status:${NC}"
echo -e "${BLUE}Webhook server running: $(ps aux | grep cloudflare_webhook_server | grep -v grep | wc -l)${NC}"
echo -e "${BLUE}Port 8080 status: $(netstat -ln 2>/dev/null | grep :8080 | wc -l) connections${NC}"
echo -e "${BLUE}Postfix status: $(sudo service postfix status | grep -o "running\|stopped")${NC}"

echo ""
echo -e "${YELLOW}Next steps to debug:${NC}"
echo -e "${BLUE}1. Check Cloudflare Worker logs in dashboard${NC}"
echo -e "${BLUE}2. Verify webhook URL is correct in worker${NC}"
echo -e "${BLUE}3. Test webhook manually (done above)${NC}"
echo -e "${BLUE}4. Check if bulk sender works: ./send_bulk_email.sh template.html${NC}"