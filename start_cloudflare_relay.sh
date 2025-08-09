#!/bin/bash

# SIBOU3AZA Cloudflare Email Relay Startup Script
# Initializes domain verification and starts webhook server

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}  SIBOU3AZA CLOUDFLARE RELAY${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

# Function to check if Node.js is installed
check_nodejs() {
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version)
        echo -e "${GREEN}✓ Node.js found: ${node_version}${NC}"
        return 0
    else
        echo -e "${RED}✗ Node.js not found${NC}"
        return 1
    fi
}

# Function to install Node.js if needed
install_nodejs() {
    echo -e "${YELLOW}Installing Node.js...${NC}"
    
    # Update package list
    sudo apt-get update -y
    
    # Install Node.js and npm
    sudo apt-get install -y nodejs npm
    
    if check_nodejs; then
        echo -e "${GREEN}✓ Node.js installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install Node.js${NC}"
        exit 1
    fi
}

# Function to install npm dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing npm dependencies...${NC}"
    
    if [ -f "package.json" ]; then
        npm install
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install dependencies${NC}"
            exit 1
        fi
    else
        echo -e "${RED}✗ package.json not found${NC}"
        exit 1
    fi
}

# Function to setup domain configuration
setup_domain_config() {
    echo -e "${CYAN}Setting up domain configuration...${NC}"
    
    # Check if configuration exists
    if [ -f "sibou3aza.conf" ]; then
        source sibou3aza.conf
        if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "" ]; then
            echo -e "${GREEN}✓ Using existing domain: ${DOMAIN}${NC}"
            return 0
        fi
    fi
    
    # Prompt for domain configuration
    echo -e "${YELLOW}Domain configuration needed for email relay...${NC}"
    read -p "Enter your sending domain name (e.g., yourdomain.com): " domain_input
    
    if [ -z "$domain_input" ]; then
        echo -e "${RED}Domain name is required!${NC}"
        exit 1
    fi
    
    # Verify DNS records
    echo -e "${BLUE}Verifying DNS records for: $domain_input${NC}"
    if [ -f "verify_domain.sh" ]; then
        if ./verify_domain.sh "$domain_input"; then
            echo -e "${GREEN}✓ DNS records verified successfully!${NC}"
        else
            echo -e "${YELLOW}⚠️  DNS verification failed, but continuing...${NC}"
            echo -e "${CYAN}You may need to configure DNS records for optimal delivery${NC}"
        fi
    fi
    
    # Get current IP
    CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
    
    # Update configuration
    cat > sibou3aza.conf <<CONF
# SIBOU3AZA Cloudflare Relay Configuration
DOMAIN="$domain_input"
SENDER_EMAIL="noreply@$domain_input"
SENDER_NAME="Email Relay System"
EMAIL_SUBJECT="Forwarded Email"
EMAIL_LIST="emaillist.txt"
CURRENT_IP="$CURRENT_IP"
MYHOSTNAME="$domain_input"

# Cloudflare Relay Settings
CLOUDFLARE_DOMAIN="2canrescue.online"
WEBHOOK_PORT="8080"
WEBHOOK_PATH="/webhook/email"

# Bulk Email Settings
BATCH_SIZE=1000
BATCH_DELAY=2
WORKER_COUNT=4
MAX_RETRIES=3
PROGRESS_CHECKPOINT=1000
CONF
    
    echo -e "${GREEN}✓ Domain configuration saved${NC}"
}

# Function to setup email list
setup_email_list() {
    echo -e "${CYAN}Setting up email list...${NC}"
    
    if [ -f "emaillist.txt" ]; then
        local email_count=$(grep -v "^#" emaillist.txt | grep -v "^$" | wc -l)
        if [ $email_count -gt 0 ]; then
            echo -e "${GREEN}✓ Email list found with ${email_count} addresses${NC}"
            return 0
        fi
    fi
    
    echo -e "${YELLOW}Creating sample email list...${NC}"
    cat > emaillist.txt <<EMAILLIST
# SIBOU3AZA Email List for Cloudflare Relay
# Add recipient email addresses here (one per line)
# Lines starting with # are comments

# Example addresses (replace with real ones):
# user1@example.com
# user2@example.com
# admin@yourdomain.com

# Add your email addresses below:

EMAILLIST
    
    echo -e "${GREEN}✓ Sample email list created${NC}"
    echo -e "${CYAN}Edit emaillist.txt to add your recipient addresses${NC}"
}

# Function to get Cloud Shell web preview URL
get_webhook_url() {
    echo -e "${CYAN}Getting webhook URL information...${NC}"
    
    # Try to detect Cloud Shell environment
    if [ -n "$CLOUD_SHELL" ] || [ -n "$DEVSHELL_PROJECT_ID" ]; then
        echo -e "${GREEN}✓ Google Cloud Shell environment detected${NC}"
        
        # Get project ID
        local project_id=$(gcloud config get-value project 2>/dev/null || echo "unknown")
        local region=$(gcloud config get-value compute/region 2>/dev/null || echo "us-central1")
        
        echo -e "${BLUE}Project ID: ${project_id}${NC}"
        echo -e "${BLUE}Region: ${region}${NC}"
        
        # Generate the likely webhook URL
        local webhook_url="https://8080-cs-${project_id}-default.cs-${region}.cloudshell.dev/webhook/email"
        
        echo ""
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}  CLOUDFLARE WORKER UPDATE${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo -e "${YELLOW}Update your Cloudflare Worker with this webhook URL:${NC}"
        echo -e "${CYAN}${webhook_url}${NC}"
        echo ""
        echo -e "${YELLOW}Steps to update Cloudflare Worker:${NC}"
        echo -e "${BLUE}1. Go to Cloudflare Dashboard > Workers & Pages${NC}"
        echo -e "${BLUE}2. Edit your email worker${NC}"
        echo -e "${BLUE}3. Replace the webhookUrl variable with:${NC}"
        echo -e "${CYAN}   const webhookUrl = \"${webhook_url}\";${NC}"
        echo -e "${BLUE}4. Save and deploy the worker${NC}"
        echo ""
        
        # Save webhook URL to config
        echo "WEBHOOK_URL=\"${webhook_url}\"" >> sibou3aza.conf
        
    else
        echo -e "${YELLOW}⚠️  Not running in Google Cloud Shell${NC}"
        echo -e "${CYAN}You'll need to manually configure the webhook URL${NC}"
    fi
}

# Function to start the webhook server
start_webhook_server() {
    echo -e "${CYAN}Starting Cloudflare webhook server...${NC}"
    
    # Check if server is already running
    if lsof -i :8080 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port 8080 is already in use${NC}"
        echo -e "${CYAN}Stopping existing process...${NC}"
        pkill -f "node.*cloudflare_webhook_server.js" || true
        sleep 2
    fi
    
    # Start the server
    echo -e "${GREEN}🚀 Starting webhook server on port 8080...${NC}"
    echo -e "${BLUE}Server will be accessible via Cloud Shell web preview${NC}"
    echo ""
    
    # Start server in background and capture PID
    nohup node cloudflare_webhook_server.js > webhook_server.log 2>&1 &
    local server_pid=$!
    
    # Save PID for later management
    echo $server_pid > webhook_server.pid
    
    # Wait a moment for server to start
    sleep 3
    
    # Check if server started successfully
    if ps -p $server_pid > /dev/null; then
        echo -e "${GREEN}✓ Webhook server started successfully (PID: $server_pid)${NC}"
        echo -e "${BLUE}✓ Server log: webhook_server.log${NC}"
        echo -e "${BLUE}✓ Server PID: webhook_server.pid${NC}"
        
        # Show web preview instructions
        echo ""
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}  WEB PREVIEW SETUP${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo -e "${YELLOW}To access your webhook server:${NC}"
        echo -e "${BLUE}1. Click the 'Web Preview' button in Cloud Shell${NC}"
        echo -e "${BLUE}2. Select 'Preview on port 8080'${NC}"
        echo -e "${BLUE}3. Copy the generated URL${NC}"
        echo -e "${BLUE}4. Add '/webhook/email' to the end for the webhook endpoint${NC}"
        echo ""
        
        return 0
    else
        echo -e "${RED}✗ Failed to start webhook server${NC}"
        echo -e "${CYAN}Check webhook_server.log for errors${NC}"
        return 1
    fi
}

# Function to show status and next steps
show_status() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  SYSTEM STATUS${NC}"
    echo -e "${PURPLE}================================${NC}"
    
    # Check webhook server
    if [ -f "webhook_server.pid" ]; then
        local pid=$(cat webhook_server.pid)
        if ps -p $pid > /dev/null; then
            echo -e "${GREEN}✓ Webhook server running (PID: $pid)${NC}"
        else
            echo -e "${RED}✗ Webhook server not running${NC}"
        fi
    else
        echo -e "${RED}✗ Webhook server not started${NC}"
    fi
    
    # Check configuration
    if [ -f "sibou3aza.conf" ]; then
        source sibou3aza.conf
        echo -e "${GREEN}✓ Configuration loaded${NC}"
        echo -e "${BLUE}  Domain: ${DOMAIN}${NC}"
        echo -e "${BLUE}  Cloudflare Domain: ${CLOUDFLARE_DOMAIN}${NC}"
    fi
    
    # Check email list
    if [ -f "emaillist.txt" ]; then
        local email_count=$(grep -v "^#" emaillist.txt | grep -v "^$" | wc -l)
        echo -e "${GREEN}✓ Email list: ${email_count} addresses${NC}"
    else
        echo -e "${YELLOW}⚠️  Email list not configured${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "${BLUE}1. Update your Cloudflare Worker with the webhook URL${NC}"
    echo -e "${BLUE}2. Add recipient addresses to emaillist.txt${NC}"
    echo -e "${BLUE}3. Send a test email to inbox@2canrescue.online${NC}"
    echo -e "${BLUE}4. Monitor logs: tail -f webhook_server.log${NC}"
    echo ""
    echo -e "${CYAN}Management Commands:${NC}"
    echo -e "${BLUE}• Stop server: ./stop_cloudflare_relay.sh${NC}"
    echo -e "${BLUE}• View logs: tail -f webhook_server.log${NC}"
    echo -e "${BLUE}• Check status: curl http://localhost:8080/status${NC}"
}

# Main execution
main() {
    echo -e "${CYAN}Initializing Cloudflare Email Relay System...${NC}"
    echo ""
    
    # Check and install Node.js if needed
    if ! check_nodejs; then
        install_nodejs
    fi
    
    # Install dependencies
    install_dependencies
    
    # Setup domain configuration
    setup_domain_config
    
    # Setup email list
    setup_email_list
    
    # Get webhook URL information
    get_webhook_url
    
    # Start webhook server
    if start_webhook_server; then
        show_status
    else
        echo -e "${RED}Failed to start the system${NC}"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "start")
        main
        ;;
    "status")
        show_status
        ;;
    *)
        main
        ;;
esac