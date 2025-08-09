#!/bin/bash

# Script to kill processes using port 8080

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   KILL PORT 8080 PROCESSES${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check what's using port 8080
echo -e "${CYAN}Checking what's using port 8080:${NC}"
if lsof -i :8080 >/dev/null 2>&1; then
    echo -e "${YELLOW}Processes using port 8080:${NC}"
    lsof -i :8080
    echo ""
    
    # Get PIDs using port 8080
    PIDS=$(lsof -ti :8080)
    
    if [ -n "$PIDS" ]; then
        echo -e "${YELLOW}Killing processes: $PIDS${NC}"
        for pid in $PIDS; do
            echo -e "${BLUE}Killing PID: $pid${NC}"
            kill -9 $pid 2>/dev/null || true
        done
        
        # Wait a moment
        sleep 2
        
        # Check if port is now free
        if lsof -i :8080 >/dev/null 2>&1; then
            echo -e "${RED}✗ Port 8080 still in use${NC}"
            lsof -i :8080
        else
            echo -e "${GREEN}✓ Port 8080 is now free${NC}"
        fi
    fi
else
    echo -e "${GREEN}✓ Port 8080 is already free${NC}"
fi

# Also kill any webhook server processes
echo ""
echo -e "${CYAN}Killing any webhook server processes:${NC}"
pkill -f "cloudflare_webhook_server" 2>/dev/null || true
pkill -f "node.*webhook" 2>/dev/null || true

# Clean up PID file
rm -f webhook_server.pid

echo ""
echo -e "${GREEN}Port cleanup completed!${NC}"
echo -e "${BLUE}You can now start the webhook server${NC}"