#!/bin/bash

# SIBOU3AZA3 Email Delivery Test Script
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   EMAIL DELIVERY TEST${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if configuration exists
if [ ! -f "sibou3aza.conf" ]; then
    echo -e "${RED}Configuration file not found. Please run the bulk sender first.${NC}"
    exit 1
fi

source sibou3aza.conf

# Create a small test email list
echo -e "${YELLOW}Creating test email list...${NC}"
cat > test_emails.txt <<TEST_LIST
test-cqt0d9y7a@srv1.mail-tester.com
micig89509@hostbyt.com
TEST_LIST

# Create simple test template
echo -e "${YELLOW}Creating test template...${NC}"
cat > test_template.html <<TEST_TEMPLATE
<!DOCTYPE html>
<html>
<head>
    <title>Email Delivery Test</title>
</head>
<body>
    <h1>Email Delivery Test</h1>
    <p>This is a test email to verify delivery functionality.</p>
    <p>Timestamp: $(date)</p>
</body>
</html>
TEST_TEMPLATE

echo -e "${YELLOW}Testing email delivery with 2 emails...${NC}"
echo ""

# Test 1: Check Postfix service
echo -e "${CYAN}1. Checking Postfix service...${NC}"
if systemctl is-active --quiet postfix; then
    echo -e "${GREEN}✓ Postfix is running${NC}"
else
    echo -e "${RED}✗ Postfix is not running${NC}"
    echo -e "${YELLOW}Attempting to start Postfix...${NC}"
    sudo systemctl start postfix
    if systemctl is-active --quiet postfix; then
        echo -e "${GREEN}✓ Postfix started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start Postfix${NC}"
    fi
fi
echo ""

# Test 2: Check mail queue
echo -e "${CYAN}2. Checking mail queue before test...${NC}"
QUEUE_BEFORE=$(mailq | grep -c "^[A-F0-9]" || echo "0")
echo -e "${BLUE}Emails in queue before test: $QUEUE_BEFORE${NC}"
echo ""

# Test 3: Send test emails
echo -e "${CYAN}3. Sending test emails...${NC}"

# Create test email
TEST_EMAIL="/tmp/test_email.eml"
cat > "$TEST_EMAIL" <<EMAIL_CONTENT
From: Newsletter Team <noreply@$DOMAIN>
To: test-cqt0d9y7a@srv1.mail-tester.com
Subject: Email Delivery Test - $(date)
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8
Date: $(date -R)

<!DOCTYPE html>
<html>
<head>
    <title>Email Delivery Test</title>
</head>
<body>
    <h1>Email Delivery Test</h1>
    <p>This is a test email to verify delivery functionality.</p>
    <p>Domain: $DOMAIN</p>
    <p>Timestamp: $(date)</p>
</body>
</html>
EMAIL_CONTENT

echo -e "${YELLOW}Sending test email to mail-tester...${NC}"
if /usr/sbin/sendmail -t < "$TEST_EMAIL" 2>&1; then
    echo -e "${GREEN}✓ Sendmail command executed successfully${NC}"
else
    echo -e "${RED}✗ Sendmail command failed${NC}"
fi

# Wait a moment for mail to process
echo -e "${YELLOW}Waiting 5 seconds for mail processing...${NC}"
sleep 5

# Test 4: Check mail queue after
echo -e "${CYAN}4. Checking mail queue after test...${NC}"
QUEUE_AFTER=$(mailq | grep -c "^[A-F0-9]" || echo "0")
echo -e "${BLUE}Emails in queue after test: $QUEUE_AFTER${NC}"

if [ $QUEUE_AFTER -gt $QUEUE_BEFORE ]; then
    echo -e "${YELLOW}⚠️  Emails are stuck in queue - there may be delivery issues${NC}"
    echo -e "${YELLOW}Queue contents:${NC}"
    mailq
else
    echo -e "${GREEN}✓ No emails stuck in queue${NC}"
fi
echo ""

# Test 5: Check mail logs
echo -e "${CYAN}5. Checking recent mail logs...${NC}"
if [ -f "/var/log/mail.log" ]; then
    echo -e "${YELLOW}Recent mail log entries:${NC}"
    sudo tail -20 /var/log/mail.log | grep -E "($(date '+%b %d %H'):|sent|delivered|bounced|rejected)"
else
    echo -e "${RED}Mail log not found at /var/log/mail.log${NC}"
fi
echo ""

# Test 6: Check postfix configuration
echo -e "${CYAN}6. Checking key Postfix configuration...${NC}"
if [ -f "/etc/postfix/main.cf" ]; then
    echo -e "${YELLOW}Key Postfix settings:${NC}"
    grep -E "^(myhostname|mydomain|inet_interfaces|relayhost)" /etc/postfix/main.cf
else
    echo -e "${RED}Postfix configuration not found${NC}"
fi
echo ""

# Test 7: Test DNS resolution
echo -e "${CYAN}7. Testing DNS resolution for mail servers...${NC}"
for email in "test-cqt0d9y7a@srv1.mail-tester.com" "micig89509@hostbyt.com"; do
    domain=$(echo "$email" | cut -d'@' -f2)
    echo -e "${YELLOW}Testing MX record for $domain:${NC}"
    if mx_record=$(dig MX "$domain" +short 2>/dev/null); then
        if [ -n "$mx_record" ]; then
            echo -e "${GREEN}✓ MX record found: $mx_record${NC}"
        else
            echo -e "${RED}✗ No MX record found for $domain${NC}"
        fi
    else
        echo -e "${RED}✗ DNS lookup failed for $domain${NC}"
    fi
done
echo ""

# Summary and recommendations
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   TEST SUMMARY${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

echo -e "${YELLOW}Next steps to verify delivery:${NC}"
echo -e "${GREEN}1. Check mail-tester.com for the test email${NC}"
echo -e "${GREEN}2. Monitor mail logs: sudo tail -f /var/log/mail.log${NC}"
echo -e "${GREEN}3. Check queue status: mailq${NC}"
echo -e "${GREEN}4. Verify your domain's reputation${NC}"
echo ""

echo -e "${YELLOW}If emails are not being delivered:${NC}"
echo -e "${CYAN}• Check if port 25 is blocked (common in cloud environments)${NC}"
echo -e "${CYAN}• Verify DNS records are properly configured${NC}"
echo -e "${CYAN}• Check if your server IP is blacklisted${NC}"
echo -e "${CYAN}• Consider using an SMTP relay service${NC}"
echo ""

# Cleanup
rm -f "$TEST_EMAIL" test_template.html test_emails.txt
