#!/bin/bash

# SIBOU3AZA Cloudflare Email Relay Stop Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}  STOPPING CLOUDFLARE RELAY${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

# Function to stop webhook server
stop_webhook_server() {
    echo -e "${YELLOW}Stopping webhook server...${NC}"
    
    # Check if PID file exists
    if [ -f "webhook_server.pid" ]; then
        local pid=$(cat webhook_server.pid)
        
        if ps -p $pid > /dev/null; then
            echo -e "${BLUE}Found running server (PID: $pid)${NC}"
            
            # Try graceful shutdown first
            kill $pid
            
            # Wait for graceful shutdown
            local count=0
            while ps -p $pid > /dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
                echo -e "${CYAN}Waiting for graceful shutdown... ($count/10)${NC}"
            done
            
            # Force kill if still running
            if ps -p $pid > /dev/null; then
                echo -e "${YELLOW}Force stopping server...${NC}"
                kill -9 $pid
                sleep 1
            fi
            
            if ps -p $pid > /dev/null; then
                echo -e "${RED}✗ Failed to stop server${NC}"
                return 1
            else
                echo -e "${GREEN}✓ Server stopped successfully${NC}"
                rm -f webhook_server.pid
                return 0
            fi
        else
            echo -e "${YELLOW}Server not running (stale PID file)${NC}"
            rm -f webhook_server.pid
        fi
    else
        echo -e "${YELLOW}No PID file found${NC}"
    fi
    
    # Kill any remaining processes
    local remaining=$(pgrep -f "node.*cloudflare_webhook_server.js" | wc -l)
    if [ $remaining -gt 0 ]; then
        echo -e "${YELLOW}Stopping $remaining remaining process(es)...${NC}"
        pkill -f "node.*cloudflare_webhook_server.js"
        sleep 2
        echo -e "${GREEN}✓ All processes stopped${NC}"
    fi
    
    return 0
}

# Function to show final status
show_final_status() {
    echo ""
    echo -e "${CYAN}Final Status:${NC}"
    
    # Check if any processes are still running
    local running_processes=$(pgrep -f "node.*cloudflare_webhook_server.js" | wc -l)
    if [ $running_processes -eq 0 ]; then
        echo -e "${GREEN}✓ No webhook server processes running${NC}"
    else
        echo -e "${RED}✗ $running_processes process(es) still running${NC}"
    fi
    
    # Check port 8080
    if lsof -i :8080 >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port 8080 still in use${NC}"
    else
        echo -e "${GREEN}✓ Port 8080 is free${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}Log files preserved:${NC}"
    if [ -f "webhook_server.log" ]; then
        local log_size=$(du -h webhook_server.log | cut -f1)
        echo -e "${CYAN}• webhook_server.log (${log_size})${NC}"
    fi
    
    if [ -d "webhook_logs" ]; then
        local log_count=$(find webhook_logs -name "*.log" | wc -l)
        echo -e "${CYAN}• webhook_logs/ (${log_count} files)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}To restart the system:${NC}"
    echo -e "${BLUE}./start_cloudflare_relay.sh${NC}"
}

# Main execution
main() {
    if stop_webhook_server; then
        show_final_status
        echo -e "${GREEN}Cloudflare Email Relay stopped successfully${NC}"
    else
        echo -e "${RED}Failed to stop some components${NC}"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "force")
        echo -e "${RED}Force stopping all processes...${NC}"
        pkill -9 -f "node.*cloudflare_webhook_server.js" || true
        rm -f webhook_server.pid
        echo -e "${GREEN}✓ Force stop completed${NC}"
        ;;
    *)
        main
        ;;
esac