#!/bin/bash

# Debug script for webhook server issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   WEBHOOK DEBUG SCRIPT${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if webhook server log exists
if [ -f "webhook_server.log" ]; then
    echo -e "${CYAN}Webhook server log contents:${NC}"
    cat webhook_server.log
    echo ""
else
    echo -e "${YELLOW}No webhook_server.log found${NC}"
fi

# Check Node.js version
echo -e "${CYAN}Node.js version:${NC}"
node --version
echo ""

# Check if port 8080 is in use
echo -e "${CYAN}Checking port 8080:${NC}"
if lsof -i :8080 >/dev/null 2>&1; then
    echo -e "${RED}Port 8080 is in use:${NC}"
    lsof -i :8080
else
    echo -e "${GREEN}Port 8080 is free${NC}"
fi
echo ""

# Test webhook server directly
echo -e "${CYAN}Testing webhook server directly:${NC}"
echo -e "${YELLOW}Starting server in foreground...${NC}"
node cloudflare_webhook_server.js &
SERVER_PID=$!

# Wait a moment
sleep 3

# Check if server started
if ps -p $SERVER_PID > /dev/null; then
    echo -e "${GREEN}✓ Server started successfully (PID: $SERVER_PID)${NC}"
    
    # Test health endpoint
    echo -e "${CYAN}Testing health endpoint:${NC}"
    curl -s http://localhost:8080/health | head -10
    echo ""
    
    # Kill the test server
    kill $SERVER_PID
    echo -e "${YELLOW}Test server stopped${NC}"
else
    echo -e "${RED}✗ Server failed to start${NC}"
    echo -e "${CYAN}Checking for error output:${NC}"
    wait $SERVER_PID
fi

echo ""
echo -e "${CYAN}Checking dependencies:${NC}"
if [ -d "node_modules" ]; then
    echo -e "${GREEN}✓ node_modules exists${NC}"
    if [ -d "node_modules/express" ]; then
        echo -e "${GREEN}✓ express installed${NC}"
    else
        echo -e "${RED}✗ express not found${NC}"
    fi
    if [ -d "node_modules/mailparser" ]; then
        echo -e "${GREEN}✓ mailparser installed${NC}"
    else
        echo -e "${RED}✗ mailparser not found${NC}"
    fi
else
    echo -e "${RED}✗ node_modules not found${NC}"
    echo -e "${YELLOW}Run: npm install${NC}"
fi

echo ""
echo -e "${CYAN}Quick fixes to try:${NC}"
echo -e "${BLUE}1. Replace package.json: cp package_fixed.json package.json${NC}"
echo -e "${BLUE}2. Clean install: rm -rf node_modules && npm install${NC}"
echo -e "${BLUE}3. Start manually: node cloudflare_webhook_server.js${NC}"
echo -e "${BLUE}4. Check logs: cat webhook_server.log${NC}"