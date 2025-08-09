#!/bin/bash

# SIBOU3AZA2 - Complete Workflow Script
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA2 Complete Workflow${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

show_workflow() {
    echo -e "${YELLOW}📋 SIBOU3AZA3 ULTRA-STREAMLINED WORKFLOW:${NC}"
    echo ""
    echo -e "${BLUE}Phase 1: Setup (One-time)${NC}"
    echo -e "${GREEN}1. sudo ./setup_mailer.sh       ${YELLOW}# Setup authentication${NC}"
    echo -e "${GREEN}2. Add DNS records               ${YELLOW}# From setup output${NC}"
    echo -e "${GREEN}3. ./verify_domain.sh domain    ${YELLOW}# Verify DNS${NC}"
    echo -e "${GREEN}4. nano emaillist.txt           ${YELLOW}# Create mailing list${NC}"
    echo ""
    echo -e "${BLUE}Phase 2: Create & Send${NC}"
    echo -e "${GREEN}5. Create template.html          ${YELLOW}# Your custom HTML email${NC}"
    echo -e "${GREEN}6. ./send_bulk_email.sh template.html ${YELLOW}# Send to all subscribers${NC}"
    echo ""
    echo -e "${BLUE}Key Features:${NC}"
    echo -e "${GREEN}✓ Ultra-simple: Create HTML → Send${NC}"
    echo -e "${GREEN}✓ Fast bulk sending (2s delay optimized)${NC}"
    echo -e "${GREEN}✓ Professional DKIM/SPF/DMARC authentication${NC}"
    echo -e "${GREEN}✓ Automatic sender rotation for bulk campaigns${NC}"
    echo -e "${GREEN}✓ You control the HTML template completely${NC}"
    echo ""
}

show_current_status() {
    echo -e "${YELLOW}📊 CURRENT STATUS:${NC}"
    echo ""
    
    # Check if config exists
    if [ -f "sibou3aza.conf" ]; then
        source sibou3aza.conf
        echo -e "${GREEN}✓ Configuration loaded${NC}"
        echo -e "${BLUE}  Domain: $DOMAIN${NC}"
        echo -e "${BLUE}  Sender Email: $SENDER_EMAIL${NC}"
    else
        echo -e "${RED}✗ Configuration not found${NC}"
        echo -e "${YELLOW}  Run: sudo ./setup_mailer.sh${NC}"
        return
    fi
    
    # Check DNS
    echo -e "${YELLOW}Checking DNS...${NC}"
    if ./verify_domain.sh "$DOMAIN" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ DNS records verified${NC}"
    else
        echo -e "${RED}✗ DNS verification failed${NC}"
        echo -e "${YELLOW}  Add DNS records and verify${NC}"
        return
    fi
    
    # Check mailing list
    if [ -f "$EMAIL_LIST" ]; then
        local list_count=$(grep -v "^#" "$EMAIL_LIST" | grep -v "^$" | wc -l)
        echo -e "${GREEN}✓ Mailing list: $EMAIL_LIST ($list_count addresses)${NC}"
    else
        echo -e "${RED}✗ Mailing list not found${NC}"
        echo -e "${YELLOW}  Create: nano $EMAIL_LIST${NC}"
        return
    fi
    
    echo -e "${GREEN}🚀 System ready for direct email sending!${NC}"
}

show_commands() {
    echo -e "${YELLOW}🔧 AVAILABLE COMMANDS:${NC}"
    echo ""
    echo -e "${BLUE}Setup Commands:${NC}"
    echo -e "${GREEN}  ./workflow.sh setup      ${YELLOW}# Run complete setup${NC}"
    echo -e "${GREEN}  ./workflow.sh status     ${YELLOW}# Check current status${NC}"
    echo ""
    echo -e "${BLUE}Email Sending:${NC}"
    echo -e "${GREEN}  ./send_bulk_email.sh template.html ${YELLOW}# Send your HTML template${NC}"
    echo -e "${GREEN}  ./send_html_email.sh template.html ${YELLOW}# Send regular HTML emails${NC}"
    echo ""
    echo -e "${BLUE}Utilities:${NC}"
    echo -e "${GREEN}  ./verify_domain.sh domain ${YELLOW}# Verify DNS${NC}"
    echo -e "${GREEN}  sudo service postfix status ${YELLOW}# Check mail service${NC}"
    echo -e "${GREEN}  sudo tail -f /var/log/mail.log ${YELLOW}# View mail logs${NC}"
}

run_setup() {
    echo -e "${YELLOW}🚀 Running streamlined SIBOU3AZA3 setup...${NC}"
    echo ""
    
    echo -e "${BLUE}Step 1: Initial setup...${NC}"
    if [ ! -f "sibou3aza.conf" ]; then
        echo -e "${YELLOW}Run: sudo ./setup_mailer.sh${NC}"
        echo -e "${YELLOW}Then add DNS records and come back${NC}"
        return
    fi
    
    source sibou3aza.conf
    
    echo -e "${BLUE}Step 2: Verify DNS...${NC}"
    if ! ./verify_domain.sh "$DOMAIN"; then
        echo -e "${RED}DNS verification failed!${NC}"
        echo -e "${YELLOW}Add DNS records first${NC}"
        return
    fi
    
    echo -e "${BLUE}Step 3: Check mailing list...${NC}"
    if [ ! -f "$EMAIL_LIST" ]; then
        echo -e "${YELLOW}Creating sample mailing list...${NC}"
        cat > "$EMAIL_LIST" <<EOF
# Add your email addresses here (one per line)
# Lines starting with # are comments
test@example.com
# user@domain.com
EOF
        echo -e "${GREEN}Created: $EMAIL_LIST${NC}"
        echo -e "${YELLOW}Edit it with: nano $EMAIL_LIST${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Setup completed!${NC}"
    echo -e "${YELLOW}Next: Create your template.html file${NC}"
    echo -e "${YELLOW}Then send with: ./send_bulk_email.sh template.html${NC}"
}

# Main execution
case "${1:-help}" in
    "workflow"|"help")
        show_workflow
        ;;
    "status")
        show_current_status
        ;;
    "commands")
        show_commands
        ;;
    "setup")
        run_setup
        ;;
    *)
        show_workflow
        echo ""
        show_commands
        echo ""
        echo -e "${YELLOW}Usage: ./workflow.sh {workflow|status|commands|setup}${NC}"
        ;;
esac
