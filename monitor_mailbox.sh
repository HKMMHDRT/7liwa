#!/bin/bash

# SIBOU3AZA Mailbox Monitor
# Continuously monitors mailbox for new emails and auto-processes them

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_NAME="SIBOU3AZA Mailbox Monitor"
PID_FILE="/tmp/sibou3aza_monitor.pid"
LOG_FILE="/opt/sibou3aza/logs/monitor.log"
CHECK_INTERVAL=30  # Check every 30 seconds
MAX_RETRIES=3

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to check if monitor is already running
is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        else
            rm -f "$PID_FILE"  # Stale PID file
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

# Function to start monitoring
start_monitor() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   ${SCRIPT_NAME}${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    # Check if already running
    if is_running; then
        echo -e "${YELLOW}Monitor is already running (PID: $(cat "$PID_FILE"))${NC}"
        echo -e "${CYAN}Use './monitor_mailbox.sh stop' to stop it first${NC}"
        exit 1
    fi
    
    # Load configuration
    if [ -f "sibou3aza.conf" ]; then
        source sibou3aza.conf
    else
        echo -e "${RED}Configuration file not found. Please run setup_mailbox.sh first.${NC}"
        exit 1
    fi
    
    # Check if mailbox is configured
    if [ -z "$MAILBOX_EMAIL" ] || [ -z "$MAILBOX_PATH" ]; then
        echo -e "${RED}Mailbox not configured. Please run setup_mailbox.sh first.${NC}"
        exit 1
    fi
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    
    echo -e "${GREEN}Starting mailbox monitoring...${NC}"
    echo -e "${BLUE}Mailbox: ${MAILBOX_EMAIL}${NC}"
    echo -e "${BLUE}Path: ${MAILBOX_PATH}${NC}"
    echo -e "${BLUE}Check interval: ${CHECK_INTERVAL} seconds${NC}"
    echo -e "${BLUE}Log file: ${LOG_FILE}${NC}"
    echo ""
    
    # Start monitoring in background
    (monitor_loop) &
    local monitor_pid=$!
    
    # Save PID
    echo "$monitor_pid" > "$PID_FILE"
    
    echo -e "${GREEN}✓ Monitor started successfully (PID: $monitor_pid)${NC}"
    echo -e "${CYAN}Monitor is running in the background${NC}"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "${BLUE}  ./monitor_mailbox.sh status   - Check monitor status${NC}"
    echo -e "${BLUE}  ./monitor_mailbox.sh logs     - View recent logs${NC}"
    echo -e "${BLUE}  ./monitor_mailbox.sh stop     - Stop monitoring${NC}"
    echo -e "${BLUE}  tail -f ${LOG_FILE} - Live log monitoring${NC}"
    
    log_message "INFO" "Mailbox monitor started (PID: $monitor_pid)"
}

# Main monitoring loop
monitor_loop() {
    local consecutive_errors=0
    
    log_message "INFO" "Monitoring loop started for mailbox: $MAILBOX_EMAIL"
    
    while true; do
        # Check for new emails
        if [ -d "$MAILBOX_PATH/new" ]; then
            local new_email_count=$(find "$MAILBOX_PATH/new" -type f 2>/dev/null | wc -l)
            
            if [ "$new_email_count" -gt 0 ]; then
                log_message "INFO" "Found $new_email_count new email(s) - processing..."
                
                # Process emails
                if ./process_emails.sh process >> "$LOG_FILE" 2>&1; then
                    log_message "SUCCESS" "Successfully processed $new_email_count email(s)"
                    consecutive_errors=0
                else
                    log_message "ERROR" "Failed to process emails"
                    consecutive_errors=$((consecutive_errors + 1))
                    
                    # Stop monitoring if too many consecutive errors
                    if [ $consecutive_errors -ge $MAX_RETRIES ]; then
                        log_message "CRITICAL" "Too many consecutive errors ($consecutive_errors). Stopping monitor."
                        break
                    fi
                fi
            fi
        else
            log_message "ERROR" "Mailbox directory not found: $MAILBOX_PATH/new"
            consecutive_errors=$((consecutive_errors + 1))
            
            if [ $consecutive_errors -ge $MAX_RETRIES ]; then
                log_message "CRITICAL" "Mailbox directory issues. Stopping monitor."
                break
            fi
        fi
        
        # Wait before next check
        sleep "$CHECK_INTERVAL"
    done
    
    log_message "INFO" "Monitoring loop ended"
    rm -f "$PID_FILE"
}

# Function to stop monitoring
stop_monitor() {
    echo -e "${YELLOW}Stopping mailbox monitor...${NC}"
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null
        
        # Wait for process to stop
        local count=0
        while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        if ps -p "$pid" > /dev/null 2>&1; then
            # Force kill if still running
            kill -9 "$pid" 2>/dev/null
            echo -e "${YELLOW}Force stopped monitor (PID: $pid)${NC}"
        else
            echo -e "${GREEN}✓ Monitor stopped successfully (PID: $pid)${NC}"
        fi
        
        rm -f "$PID_FILE"
        log_message "INFO" "Mailbox monitor stopped"
    else
        echo -e "${YELLOW}Monitor is not running${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   MONITOR STATUS${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    
    if is_running; then
        local pid=$(cat "$PID_FILE")
        local uptime=$(ps -o etime= -p "$pid" 2>/dev/null | tr -d ' ')
        echo -e "${GREEN}✓ Monitor is running${NC}"
        echo -e "${BLUE}  PID: $pid${NC}"
        echo -e "${BLUE}  Uptime: $uptime${NC}"
        echo -e "${BLUE}  Log file: $LOG_FILE${NC}"
    else
        echo -e "${RED}✗ Monitor is not running${NC}"
    fi
    
    # Show recent activity
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo -e "${CYAN}Recent activity (last 10 entries):${NC}"
        tail -10 "$LOG_FILE" | while read -r line; do
            if echo "$line" | grep -q "ERROR\|CRITICAL"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q "SUCCESS"; then
                echo -e "${GREEN}$line${NC}"
            elif echo "$line" | grep -q "INFO"; then
                echo -e "${BLUE}$line${NC}"
            else
                echo -e "${YELLOW}$line${NC}"
            fi
        done
    fi
    
    # Show mailbox status
    if [ -f "sibou3aza.conf" ]; then
        source sibou3aza.conf
        if [ -n "$MAILBOX_PATH" ] && [ -d "$MAILBOX_PATH/new" ]; then
            local new_emails=$(find "$MAILBOX_PATH/new" -type f 2>/dev/null | wc -l)
            echo ""
            echo -e "${CYAN}Mailbox status:${NC}"
            echo -e "${BLUE}  Email address: $MAILBOX_EMAIL${NC}"
            echo -e "${BLUE}  New emails waiting: $new_emails${NC}"
        fi
    fi
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo -e "${CYAN}Recent monitor logs:${NC}"
        echo ""
        tail -20 "$LOG_FILE" | while read -r line; do
            if echo "$line" | grep -q "ERROR\|CRITICAL"; then
                echo -e "${RED}$line${NC}"
            elif echo "$line" | grep -q "SUCCESS"; then
                echo -e "${GREEN}$line${NC}"
            elif echo "$line" | grep -q "INFO"; then
                echo -e "${BLUE}$line${NC}"
            else
                echo -e "${YELLOW}$line${NC}"
            fi
        done
        echo ""
        echo -e "${CYAN}For live monitoring: tail -f $LOG_FILE${NC}"
    else
        echo -e "${YELLOW}No log file found. Monitor has not been started yet.${NC}"
    fi
}

# Function to restart monitoring
restart_monitor() {
    echo -e "${YELLOW}Restarting mailbox monitor...${NC}"
    stop_monitor
    sleep 2
    start_monitor
}

# Function to show help
show_help() {
    echo -e "${BLUE}SIBOU3AZA Mailbox Monitor${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "${CYAN}  ./monitor_mailbox.sh start     ${NC}- Start monitoring mailbox"
    echo -e "${CYAN}  ./monitor_mailbox.sh stop      ${NC}- Stop monitoring"
    echo -e "${CYAN}  ./monitor_mailbox.sh restart   ${NC}- Restart monitoring"
    echo -e "${CYAN}  ./monitor_mailbox.sh status    ${NC}- Show monitor status"
    echo -e "${CYAN}  ./monitor_mailbox.sh logs      ${NC}- Show recent logs"
    echo -e "${CYAN}  ./monitor_mailbox.sh help      ${NC}- Show this help"
    echo ""
    echo -e "${YELLOW}Description:${NC}"
    echo "This script continuously monitors your mailbox for new emails"
    echo "and automatically processes them by forwarding to your mailing list."
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo -e "${BLUE}Check interval: ${CHECK_INTERVAL} seconds${NC}"
    echo -e "${BLUE}Log file: ${LOG_FILE}${NC}"
    echo -e "${BLUE}PID file: ${PID_FILE}${NC}"
}

# Main execution
case "${1:-}" in
    "start")
        start_monitor
        ;;
    "stop")
        stop_monitor
        ;;
    "restart")
        restart_monitor
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo -e "${RED}Invalid command: ${1:-}${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
