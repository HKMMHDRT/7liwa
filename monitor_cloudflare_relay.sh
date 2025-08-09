#!/bin/bash

# SIBOU3AZA Cloudflare Email Relay Monitor
# Provides real-time monitoring and status information

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
REFRESH_INTERVAL=5
LOG_LINES=20

# Function to clear screen and show header
show_header() {
    clear
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}  CLOUDFLARE RELAY MONITOR${NC}"
    echo -e "${PURPLE}  $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
}

# Function to check system status
check_system_status() {
    echo -e "${CYAN}System Status:${NC}"
    
    # Check webhook server
    local server_status="STOPPED"
    local server_pid=""
    local server_uptime=""
    
    if [ -f "webhook_server.pid" ]; then
        server_pid=$(cat webhook_server.pid)
        if ps -p $server_pid > /dev/null 2>&1; then
            server_status="RUNNING"
            server_uptime=$(ps -o etime= -p $server_pid 2>/dev/null | tr -d ' ')
        else
            server_status="STOPPED (stale PID)"
        fi
    fi
    
    if [ "$server_status" = "RUNNING" ]; then
        echo -e "${GREEN}✓ Webhook Server: $server_status (PID: $server_pid, Uptime: $server_uptime)${NC}"
    else
        echo -e "${RED}✗ Webhook Server: $server_status${NC}"
    fi
    
    # Check port 8080
    if lsof -i :8080 >/dev/null 2>&1; then
        local port_process=$(lsof -i :8080 -t 2>/dev/null | head -1)
        echo -e "${GREEN}✓ Port 8080: In use (PID: $port_process)${NC}"
    else
        echo -e "${RED}✗ Port 8080: Not in use${NC}"
    fi
    
    # Check configuration
    if [ -f "sibou3aza.conf" ]; then
        source sibou3aza.conf
        echo -e "${GREEN}✓ Configuration: Loaded${NC}"
        echo -e "${BLUE}  Domain: ${DOMAIN:-'Not set'}${NC}"
        echo -e "${BLUE}  Cloudflare Domain: ${CLOUDFLARE_DOMAIN:-'Not set'}${NC}"
        
        if [ -n "$WEBHOOK_URL" ]; then
            echo -e "${BLUE}  Webhook URL: ${WEBHOOK_URL}${NC}"
        fi
    else
        echo -e "${RED}✗ Configuration: Not found${NC}"
    fi
    
    # Check email list
    if [ -f "emaillist.txt" ]; then
        local email_count=$(grep -v "^#" emaillist.txt | grep -v "^$" | wc -l)
        if [ $email_count -gt 0 ]; then
            echo -e "${GREEN}✓ Email List: ${email_count} recipients${NC}"
        else
            echo -e "${YELLOW}⚠️  Email List: Empty${NC}"
        fi
    else
        echo -e "${RED}✗ Email List: Not found${NC}"
    fi
    
    echo ""
}

# Function to show webhook statistics
show_webhook_stats() {
    echo -e "${CYAN}Webhook Statistics:${NC}"
    
    # Check if server is responding
    local health_status="UNKNOWN"
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        health_status="HEALTHY"
        echo -e "${GREEN}✓ Health Check: $health_status${NC}"
        
        # Get detailed stats from server
        local stats=$(curl -s http://localhost:8080/status 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo -e "${BLUE}✓ Server API: Responding${NC}"
        fi
    else
        health_status="UNHEALTHY"
        echo -e "${RED}✗ Health Check: $health_status${NC}"
    fi
    
    # Count log entries
    if [ -d "webhook_logs" ]; then
        local today=$(date '+%Y-%m-%d')
        local today_log="webhook_logs/webhook_${today}.log"
        
        if [ -f "$today_log" ]; then
            local total_requests=$(grep -c '"level":"INFO"' "$today_log" 2>/dev/null || echo "0")
            local successful_requests=$(grep -c '"level":"SUCCESS"' "$today_log" 2>/dev/null || echo "0")
            local failed_requests=$(grep -c '"level":"ERROR"' "$today_log" 2>/dev/null || echo "0")
            
            echo -e "${BLUE}Today's Activity:${NC}"
            echo -e "${CYAN}  Total Requests: $total_requests${NC}"
            echo -e "${GREEN}  Successful: $successful_requests${NC}"
            echo -e "${RED}  Failed: $failed_requests${NC}"
        else
            echo -e "${YELLOW}⚠️  No activity today${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No webhook logs directory${NC}"
    fi
    
    echo ""
}

# Function to show recent activity
show_recent_activity() {
    echo -e "${CYAN}Recent Activity (Last $LOG_LINES entries):${NC}"
    
    # Show server log if available
    if [ -f "webhook_server.log" ]; then
        echo -e "${BLUE}Server Log:${NC}"
        tail -$LOG_LINES webhook_server.log | while read -r line; do
            if echo "$line" | grep -q "ERROR\|error"; then
                echo -e "${RED}  $line${NC}"
            elif echo "$line" | grep -q "SUCCESS\|✓"; then
                echo -e "${GREEN}  $line${NC}"
            elif echo "$line" | grep -q "WARNING\|⚠️"; then
                echo -e "${YELLOW}  $line${NC}"
            else
                echo -e "${CYAN}  $line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No server log available${NC}"
    fi
    
    echo ""
    
    # Show webhook logs if available
    local today=$(date '+%Y-%m-%d')
    local today_log="webhook_logs/webhook_${today}.log"
    
    if [ -f "$today_log" ]; then
        echo -e "${BLUE}Webhook Activity:${NC}"
        tail -5 "$today_log" | while read -r line; do
            local level=$(echo "$line" | grep -o '"level":"[^"]*"' | cut -d'"' -f4)
            local message=$(echo "$line" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            local timestamp=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)
            
            case "$level" in
                "SUCCESS")
                    echo -e "${GREEN}  [$timestamp] $message${NC}"
                    ;;
                "ERROR")
                    echo -e "${RED}  [$timestamp] $message${NC}"
                    ;;
                "WARNING")
                    echo -e "${YELLOW}  [$timestamp] $message${NC}"
                    ;;
                *)
                    echo -e "${CYAN}  [$timestamp] $message${NC}"
                    ;;
            esac
        done
    else
        echo -e "${YELLOW}⚠️  No webhook activity today${NC}"
    fi
    
    echo ""
}

# Function to show system resources
show_system_resources() {
    echo -e "${CYAN}System Resources:${NC}"
    
    # Memory usage
    local memory_info=$(free -h | grep "Mem:")
    local memory_used=$(echo $memory_info | awk '{print $3}')
    local memory_total=$(echo $memory_info | awk '{print $2}')
    echo -e "${BLUE}Memory: $memory_used / $memory_total${NC}"
    
    # Disk usage for current directory
    local disk_usage=$(du -sh . 2>/dev/null | cut -f1)
    echo -e "${BLUE}Disk Usage (current dir): $disk_usage${NC}"
    
    # Load average
    local load_avg=$(uptime | grep -o 'load average:.*' | cut -d' ' -f3-5)
    echo -e "${BLUE}Load Average: $load_avg${NC}"
    
    echo ""
}

# Function to show control commands
show_controls() {
    echo -e "${CYAN}Controls:${NC}"
    echo -e "${BLUE}[q] Quit monitor${NC}"
    echo -e "${BLUE}[r] Refresh now${NC}"
    echo -e "${BLUE}[l] View full logs${NC}"
    echo -e "${BLUE}[s] Start/Stop server${NC}"
    echo -e "${BLUE}[t] Test webhook${NC}"
    echo ""
    echo -e "${YELLOW}Auto-refresh every ${REFRESH_INTERVAL} seconds${NC}"
    echo -e "${YELLOW}Press any key to continue...${NC}"
}

# Function to test webhook
test_webhook() {
    echo -e "${CYAN}Testing webhook endpoint...${NC}"
    
    local test_result=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null)
    
    if [ "$test_result" = "200" ]; then
        echo -e "${GREEN}✓ Webhook endpoint responding (HTTP 200)${NC}"
    else
        echo -e "${RED}✗ Webhook endpoint not responding (HTTP $test_result)${NC}"
    fi
    
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -n 1
}

# Function to view full logs
view_full_logs() {
    echo -e "${CYAN}Select log to view:${NC}"
    echo -e "${BLUE}1) Server log (webhook_server.log)${NC}"
    echo -e "${BLUE}2) Today's webhook log${NC}"
    echo -e "${BLUE}3) All webhook logs${NC}"
    echo -e "${BLUE}4) Back to monitor${NC}"
    
    read -p "Choice (1-4): " log_choice
    
    case $log_choice in
        1)
            if [ -f "webhook_server.log" ]; then
                less webhook_server.log
            else
                echo -e "${RED}Server log not found${NC}"
                sleep 2
            fi
            ;;
        2)
            local today=$(date '+%Y-%m-%d')
            local today_log="webhook_logs/webhook_${today}.log"
            if [ -f "$today_log" ]; then
                less "$today_log"
            else
                echo -e "${RED}Today's webhook log not found${NC}"
                sleep 2
            fi
            ;;
        3)
            if [ -d "webhook_logs" ]; then
                ls -la webhook_logs/
                echo -e "${YELLOW}Press any key to continue...${NC}"
                read -n 1
            else
                echo -e "${RED}Webhook logs directory not found${NC}"
                sleep 2
            fi
            ;;
        4)
            return
            ;;
    esac
}

# Function to start/stop server
toggle_server() {
    if [ -f "webhook_server.pid" ]; then
        local pid=$(cat webhook_server.pid)
        if ps -p $pid > /dev/null 2>&1; then
            echo -e "${YELLOW}Stopping server...${NC}"
            ./stop_cloudflare_relay.sh
        else
            echo -e "${YELLOW}Starting server...${NC}"
            ./start_cloudflare_relay.sh
        fi
    else
        echo -e "${YELLOW}Starting server...${NC}"
        ./start_cloudflare_relay.sh
    fi
    
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -n 1
}

# Main monitoring loop
monitor_loop() {
    while true; do
        show_header
        check_system_status
        show_webhook_stats
        show_recent_activity
        show_system_resources
        show_controls
        
        # Wait for input with timeout
        if read -t $REFRESH_INTERVAL -n 1 key; then
            case $key in
                'q'|'Q')
                    echo -e "\n${GREEN}Exiting monitor...${NC}"
                    exit 0
                    ;;
                'r'|'R')
                    continue
                    ;;
                'l'|'L')
                    view_full_logs
                    ;;
                's'|'S')
                    toggle_server
                    ;;
                't'|'T')
                    test_webhook
                    ;;
            esac
        fi
    done
}

# Function to show simple status (non-interactive)
show_simple_status() {
    echo -e "${PURPLE}SIBOU3AZA Cloudflare Relay Status${NC}"
    echo -e "${PURPLE}$(date)${NC}"
    echo ""
    
    check_system_status
    show_webhook_stats
    
    echo -e "${CYAN}For interactive monitoring: ./monitor_cloudflare_relay.sh${NC}"
}

# Main execution
case "${1:-}" in
    "status")
        show_simple_status
        ;;
    "test")
        test_webhook
        ;;
    *)
        echo -e "${BLUE}Starting interactive monitor...${NC}"
        echo -e "${YELLOW}Press 'q' to quit, 'r' to refresh${NC}"
        sleep 2
        monitor_loop
        ;;
esac