#!/bin/bash

# SIBOU3AZA4 - Ultra High-Volume Bulk Email Sender
# Optimized for millions of emails with advanced batch processing and workers
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}================================${NC}"
echo -e "${PURPLE}   SIBOU3AZA4 BULK EMAIL SENDER${NC}"
echo -e "${PURPLE}   Ultra High-Volume Optimized${NC}"
echo -e "${PURPLE}================================${NC}"
echo ""

# Function to prompt for domain and configuration
setup_session_config() {
    echo -e "${YELLOW}=== CLOUD SHELL SESSION SETUP ===${NC}"
    echo ""
    
    # Prompt for domain
    read -p "Enter your domain name (e.g., yourdomain.com): " domain_input
    if [ -z "$domain_input" ]; then
        echo -e "${RED}Domain name is required!${NC}"
        exit 1
    fi
    
    # Verify DNS records first
    echo -e "${BLUE}Verifying DNS records for: $domain_input${NC}"
    if ! ./verify_domain.sh "$domain_input"; then
        echo -e "${RED}DNS verification failed. Please configure DNS records first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}DNS records verified successfully!${NC}"
    echo ""
    
    # Get current IP
    CURRENT_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
    
    # Prompt for sender email
    read -p "Enter sender email (default: noreply@$domain_input): " sender_input
    sender_input=${sender_input:-"noreply@$domain_input"}
    
    # Update configuration
    DOMAIN="$domain_input"
    SENDER_EMAIL="$sender_input"
    SENDER_NAME="Newsletter Team"
    EMAIL_SUBJECT="Newsletter Update"
    EMAIL_LIST="emaillist.txt"
    MYHOSTNAME="$domain_input"
    
    # Update config file for this session
    cat > sibou3aza.conf <<CONF
# SIBOU3AZA4 Session Configuration
DOMAIN="$DOMAIN"
SENDER_EMAIL="$SENDER_EMAIL"
SENDER_NAME="$SENDER_NAME"
EMAIL_SUBJECT="$EMAIL_SUBJECT"
EMAIL_LIST="$EMAIL_LIST"
CURRENT_IP="$CURRENT_IP"
MYHOSTNAME="$MYHOSTNAME"
BATCH_SIZE=2000
BATCH_DELAY=1
WORKER_COUNT=6
MAX_RETRIES=3
PROGRESS_CHECKPOINT=5000
CONF
    
    echo -e "${GREEN}Session configuration created successfully!${NC}"
    echo ""
}

# Check if configuration exists and is valid
if [ ! -f "sibou3aza.conf" ] || [ ! -s "sibou3aza.conf" ] || ! grep -q "DOMAIN=" sibou3aza.conf || [ "$(grep "DOMAIN=" sibou3aza.conf | cut -d'"' -f2)" = "" ]; then
    setup_session_config
fi

# Load configuration
source sibou3aza.conf

# Verify configuration is loaded
if [ -z "$DOMAIN" ] || [ -z "$SENDER_EMAIL" ]; then
    echo -e "${RED}Configuration incomplete. Setting up session...${NC}"
    setup_session_config
    source sibou3aza.conf
fi

# Function to select speed mode
select_speed_mode() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   SPEED MODE SELECTION${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
    echo -e "${YELLOW}Choose sending mode:${NC}"
    echo -e "${GREEN}1) NORMAL MODE    ${NC}- Safe, reliable (~3,000 emails/sec)"
    echo -e "${RED}2) ULTRA SPEED    ${NC}- Maximum speed (~8,000+ emails/sec)"
    echo -e "${BLUE}3) CUSTOM         ${NC}- Set your own parameters"
    echo ""
    
    while true; do
        read -p "Enter choice (1-3): " speed_choice
        case $speed_choice in
            1)
                # Normal Mode - Safe and reliable
                BATCH_SIZE=2000
                BATCH_DELAY=1
                WORKER_COUNT=6
                MODE_NAME="NORMAL MODE"
                MODE_DESC="Safe, reliable sending"
                break
                ;;
            2)
                # Ultra Speed Mode - Maximum performance
                BATCH_SIZE=10000
                BATCH_DELAY=0
                WORKER_COUNT=15
                MODE_NAME="ULTRA SPEED MODE"
                MODE_DESC="Maximum speed (bypasses spam filters with speed)"
                echo -e "${YELLOW}⚠️  Ultra Speed Mode uses speed-bypasses-filters strategy${NC}"
                echo -e "${YELLOW}⚠️  Send so fast that spam filters can't react in time${NC}"
                break
                ;;
            3)
                # Custom Mode - User defined
                echo -e "${CYAN}Custom Configuration:${NC}"
                read -p "Batch size (default 2000): " custom_batch
                read -p "Delay in seconds (default 1): " custom_delay  
                read -p "Number of workers (default 6): " custom_workers
                
                BATCH_SIZE=${custom_batch:-2000}
                BATCH_DELAY=${custom_delay:-1}
                WORKER_COUNT=${custom_workers:-6}
                MODE_NAME="CUSTOM MODE"
                MODE_DESC="User-defined configuration"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                ;;
        esac
    done
    
    # Calculate estimated performance
    local emails_per_worker_per_sec=$((BATCH_SIZE / (BATCH_DELAY + 1)))
    local total_emails_per_sec=$((emails_per_worker_per_sec * WORKER_COUNT))
    
    echo ""
    echo -e "${GREEN}✓ Selected: $MODE_NAME${NC}"
    echo -e "${BLUE}Configuration:${NC}"
    echo -e "${BLUE}• Batch Size: $BATCH_SIZE emails${NC}"
    echo -e "${BLUE}• Workers: $WORKER_COUNT parallel${NC}"
    echo -e "${BLUE}• Delay: ${BATCH_DELAY}s between batches${NC}"
    echo -e "${BLUE}• Estimated Speed: ~$total_emails_per_sec emails/second${NC}"
    echo -e "${BLUE}• Description: $MODE_DESC${NC}"
    echo ""
}

# Configuration for ultra high-volume sending (will be set by speed mode selection)
BATCH_SIZE=2000           # Emails per batch (default, will be overridden)
BATCH_DELAY=1            # Seconds between batches (default, will be overridden)
WORKER_COUNT=6           # Parallel workers (default, will be overridden)
MAX_RETRIES=3            # Retry failed emails
PROGRESS_CHECKPOINT=5000 # Progress update every N emails

# Auto-rotating sender pool for better deliverability
SENDER_POOL=(
    "news@$DOMAIN"
    "info@$DOMAIN" 
    "updates@$DOMAIN"
    "alerts@$DOMAIN"
    "team@$DOMAIN"
    "newsletter@$DOMAIN"
    "notifications@$DOMAIN"
    "support@$DOMAIN"
)
SENDER_NAMES=(
    "News Team"
    "Info Desk"
    "Updates"
    "Alerts"
    "Team"
    "Newsletter"
    "Notifications"
    "Support"
)

# Create working directories
mkdir -p bulk_temp
mkdir -p bulk_logs
mkdir -p bulk_progress


# Function to create the email template for a worker
create_worker_template() {
    local html_file="$1"
    local worker_id="$2"
    local output_file="$3"
    
    local subject=$(grep -i "<title>" "$html_file" | sed 's/<[^>]*>//g' | tr -d '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$subject" ] && subject="Important Update"
    
    # Rotate sender based on worker ID
    local sender_count=${#SENDER_POOL[@]}
    local sender_index=$(( (worker_id - 1) % sender_count ))
    local rotating_sender="${SENDER_POOL[$sender_index]}"
    local rotating_name="${SENDER_NAMES[$sender_index]}"
    
    cat > "$output_file" <<EOF
Return-Path: <>
From: $rotating_name <$rotating_sender>
Subject: $subject
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8
X-Mailer: SIBOU3AZA4-BulkStream
Date: $(date -R)

EOF
    cat "$html_file" >> "$output_file"
}

# The worker function that sends a single email using a pre-created template
stream_worker() {
    local worker_id=$1
    local template_file=$2
    local email=$3
    
    local worker_log="bulk_logs/worker_${worker_id}.log"
    
    email=$(echo "$email" | tr -d '\r' | xargs)
    if [[ -z "$email" || "$email" =~ ^#.* ]]; then
        return
    fi
    
    if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        (echo "Bcc: $email"; cat "$template_file") | /usr/sbin/sendmail -t 2>>"$worker_log"
        if [ $? -eq 0 ]; then
            echo "1" >> "bulk_progress/worker_${worker_id}_success.log"
            
            # Interval testing logic
            if [ "$TEST_ENABLED" = "true" ]; then
                # Use a lock file for safe concurrent access to the counter
                (
                    flock -x 200
                    # Increment shared counter
                    local total_sent=$(cat bulk_progress/total_sent_counter.txt 2>/dev/null || echo 0)
                    total_sent=$((total_sent + 1))
                    echo "$total_sent" > bulk_progress/total_sent_counter.txt
                    
                    # Check if it's time to send a test
                    if (( total_sent % TEST_INTERVAL == 0 )); then
                        send_test_email "$total_sent"
                    fi
                ) 200>bulk_progress/counter.lock
            fi
        else
            echo "1" >> "bulk_progress/worker_${worker_id}_failure.log"
        fi
    else
        echo "[$(date)] Invalid email in worker $worker_id: $email" >> "$worker_log"
        echo "1" >> "bulk_progress/worker_${worker_id}_failure.log"
    fi
}

# Function to send a test email
send_test_email() {
    local total_sent=$1
    local test_subject="[TEST] Campaign Progress Report - $total_sent emails sent"
    local test_body="This is an automated test email. The campaign has successfully sent $total_sent emails so far."
    
    # Use a specific sender for tests
    local test_sender="test-alerts@$DOMAIN"
    
    # Construct and send the email
    {
        echo "From: SIBOU3AZA4 Test Alerts <$test_sender>"
        echo "To: $TEST_EMAIL_LIST"
        echo "Subject: $test_subject"
        echo "Content-Type: text/plain"
        echo ""
        echo "$test_body"
    } | /usr/sbin/sendmail -t
    
    echo "[$(date)] Sent interval test email to $TEST_EMAIL_LIST" >> "bulk_logs/test_alerts.log"
}
export -f create_worker_template stream_worker send_test_email
export SENDER_POOL SENDER_NAMES DOMAIN TEST_ENABLED TEST_INTERVAL TEST_EMAIL_LIST WORKER_COUNT

# Function to monitor progress (simplified)
monitor_progress() {
    local total_emails="$1"
    local start_time=$(date +%s)
    
    while true; do
        # Use wc -l for accurate, high-performance counting
        local total_success=0
        local total_failure=0

        if [ -n "$(find bulk_progress -name '*_success.log' -print -quit 2>/dev/null)" ]; then
            total_success=$(cat bulk_progress/*_success.log | wc -l)
        fi
        if [ -n "$(find bulk_progress -name '*_failure.log' -print -quit 2>/dev/null)" ]; then
            total_failure=$(cat bulk_progress/*_failure.log | wc -l)
        fi
        
        local emails_processed=$((total_success + total_failure))
        local progress_percent=0
        if [ "$total_emails" -gt 0 ]; then
            progress_percent=$((emails_processed * 100 / total_emails))
        fi
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        clear
        echo -e "${PURPLE}================================${NC}"
        echo -e "${PURPLE}   SIBOU3AZA4 BULK PROGRESS${NC}"
        echo -e "${PURPLE}================================${NC}"
        echo ""
        echo -e "${CYAN}📊 Campaign Status:${NC}"
        echo -e "${BLUE}Emails Processed: $emails_processed/$total_emails (${progress_percent}%)${NC}"
        echo -e "${GREEN}✅ Successful: $total_success${NC}"
        echo -e "${RED}❌ Failed: $total_failure${NC}"
        echo -e "${YELLOW}⏱️  Elapsed: ${elapsed}s${NC}"
        
        if [ $emails_processed -gt 0 ] && [ $elapsed -gt 0 ]; then
            local rate=$((emails_processed / elapsed))
            echo -e "${CYAN}⚡ Rate: ${rate} emails/second${NC}"
        fi
        
        # Check if the main sending process is still running
        if ! pgrep -f "send_bulk_email.sh.*$html_file" >/dev/null; then
            echo ""
            echo -e "${GREEN}🎉 ALL WORKERS COMPLETED!${NC}"
            break
        fi
        
        sleep 2
    done
}

# Function to configure interval testing
setup_interval_testing() {
    echo ""
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   INTERVAL TESTING SETUP${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
    
    read -p "Enable interval testing? (y/n): " enable_testing
    if [[ "$enable_testing" =~ ^[Yy]$ ]]; then
        TEST_ENABLED="true"
        read -p "Send test email every N emails (e.g., 5000): " test_interval
        TEST_INTERVAL=${test_interval:-5000}
        
        read -p "Enter test email addresses (separated by ;): " test_emails
        TEST_EMAIL_LIST=$(echo "$test_emails" | tr -s ';' ',')
        
        echo -e "${GREEN}✓ Interval testing enabled.${NC}"
        echo -e "${BLUE}• Test Interval: Every $TEST_INTERVAL emails${NC}"
        echo -e "${BLUE}• Test Recipients: $TEST_EMAIL_LIST${NC}"
    else
        TEST_ENABLED="false"
        echo -e "${YELLOW}Interval testing disabled.${NC}"
    fi
    echo ""
}

# Function to send bulk email campaign (streamlined)
send_bulk_campaign() {
    local html_file="$1"
    
    if [ ! -f "$html_file" ]; then
        echo -e "${RED}Error: HTML file not found: $html_file${NC}"; exit 1;
    fi
    if [ ! -f "$EMAIL_LIST" ]; then
        echo -e "${RED}Error: Mailing list file not found: $EMAIL_LIST${NC}"; exit 1;
    fi
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    select_speed_mode
    setup_interval_testing
    
    echo -e "${CYAN}🚀 Starting BULK email campaign${NC}"
    echo -e "${BLUE}Mode: $MODE_NAME${NC}"
    echo -e "${BLUE}HTML file: $html_file${NC}"
    echo -e "${BLUE}Email list: $EMAIL_LIST${NC}"
    echo -e "${BLUE}Campaign ID: $timestamp${NC}"
    echo ""
    
    echo -e "${PURPLE}🔄 Automatic Sender Rotation Pool:${NC}"
    local sender_count=${#SENDER_POOL[@]}
    for ((i=0; i<sender_count; i++)); do
        echo -e "${CYAN}  ${SENDER_NAMES[$i]} <${SENDER_POOL[$i]}>${NC}"
    done
    echo -e "${BLUE}Total senders in pool: $sender_count${NC}"
    echo ""
    
    # Clean and count emails
    local clean_emails="bulk_temp/clean_emails.txt"
    grep -v "^#" "$EMAIL_LIST" | grep -v "^$" | sed 's/\r//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' > "$clean_emails"
    local total_emails=$(wc -l < "$clean_emails")
    
    # Initialize shared counter for interval testing
    if [ "$TEST_ENABLED" = "true" ]; then
        echo 0 > bulk_progress/total_sent_counter.txt
        touch bulk_progress/counter.lock
    fi
    
    echo -e "${YELLOW}Preparing to send $total_emails emails using $WORKER_COUNT workers...${NC}"
    
    local start_time=$(date +%s)
    
    # Start progress monitor in background
    monitor_progress "$total_emails" &
    local monitor_pid=$!
    
    # Launch workers and pipe emails to them
    echo -e "${GREEN}🚀 Launching $WORKER_COUNT workers...${NC}"
    
    # Export variables needed by stream_worker in sub-shells
    export WORKER_COUNT TEST_ENABLED TEST_INTERVAL TEST_EMAIL_LIST
    
    # Serialize arrays to pass as arguments
    local sender_pool_str="${SENDER_POOL[*]}"
    local sender_names_str="${SENDER_NAMES[*]}"
    
    # Create a single template that workers will use
    master_template="bulk_temp/master_template.eml"
    create_worker_template "$html_file" "1" "$master_template"

    # Use a while-read loop with xargs for robust parallel processing
    cat "$clean_emails" | xargs -P "$WORKER_COUNT" -I {} bash -c '
        worker_id=$(( (RANDOM % WORKER_COUNT) + 1 ))
        template_file="bulk_temp/master_template.eml"
        email="{}"
        
        # The actual worker function call
        stream_worker "$worker_id" "$template_file" "$email"
    '
    
    # Clean up the master template
    rm -f "$master_template"
    
    # Wait for a moment to ensure all progress files are written
    sleep 3
    
    # Stop progress monitor
    kill $monitor_pid 2>/dev/null
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Final statistics
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}   BULK CAMPAIGN COMPLETED${NC}"
    echo -e "${GREEN}================================${NC}"
    
    # Calculate final stats using the new line-counting method
    local final_success=0
    local final_failure=0
    
    if [ -n "$(find bulk_progress -name '*_success.log' -print -quit 2>/dev/null)" ]; then
        final_success=$(cat bulk_progress/*_success.log | wc -l)
    fi
    if [ -n "$(find bulk_progress -name '*_failure.log' -print -quit 2>/dev/null)" ]; then
        final_failure=$(cat bulk_progress/*_failure.log | wc -l)
    fi
    
    local total_processed=$((final_success + final_failure))
    local final_success_rate=0
    if [ "$total_processed" -gt 0 ]; then
        final_success_rate=$((final_success * 100 / total_processed))
    fi
    
    echo -e "${BLUE}Total Processed: $total_processed${NC}"
    echo -e "${GREEN}Successful: $final_success${NC}"
    echo -e "${RED}Failed: $final_failure${NC}"
    echo -e "${CYAN}Success Rate: ${final_success_rate}%${NC}"
    echo ""
    
    # Create summary
    local summary_file="bulk_campaign_${timestamp}_summary.txt"
    cat > "$summary_file" <<SUMMARY
SIBOU3AZA4 Bulk Email Campaign Summary
=====================================
Campaign ID: $timestamp
HTML File: $html_file
Email List: $EMAIL_LIST
Start Time: $(date)

Configuration:
- Batch Size: $BATCH_SIZE
- Batch Delay: ${BATCH_DELAY}s
- Workers: $WORKER_COUNT
- Return-Path: Empty (optimized for inbox delivery)

Results:
- Total Processed: $total_processed
- Successful: $final_success
- Failed: $final_failure
- Success Rate: ${final_success_rate}%
- Total Duration: ${total_duration} seconds

Log Files: bulk_logs/
Progress Files: bulk_progress/
SUMMARY
    
    echo -e "${YELLOW}📊 Summary saved: $summary_file${NC}"
    echo -e "${YELLOW}📁 Logs available in: bulk_logs/${NC}"
}

# Function to generate a summary from existing progress files
generate_summary() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}   MANUAL CAMPAIGN SUMMARY${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""
    
    if [ ! -d "bulk_progress" ]; then
        echo -e "${RED}No progress directory found. Cannot generate summary.${NC}"
        echo -e "${YELLOW}Please run a campaign first.${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Calculating results from existing progress files...${NC}"
    
    local final_success=0
    local final_failure=0
    
    if [ -n "$(find bulk_progress -name '*_success.log' -print -quit 2>/dev/null)" ]; then
        final_success=$(cat bulk_progress/*_success.log | wc -l)
    fi
    if [ -n "$(find bulk_progress -name '*_failure.log' -print -quit 2>/dev/null)" ]; then
        final_failure=$(cat bulk_progress/*_failure.log | wc -l)
    fi
    
    local total_processed=$((final_success + final_failure))
    local final_success_rate=0
    if [ "$total_processed" -gt 0 ]; then
        final_success_rate=$((final_success * 100 / total_processed))
    fi
    
    echo ""
    echo -e "${BLUE}Total Processed: $total_processed${NC}"
    echo -e "${GREEN}✅ Successful: $final_success${NC}"
    echo -e "${RED}❌ Failed: $final_failure${NC}"
    echo -e "${CYAN}📊 Success Rate: ${final_success_rate}%${NC}"
    echo ""
    echo -e "${YELLOW}Note: Duration is not available for manually generated summaries.${NC}"
}

# --- Start of Main Execution Logic ---
html_file=${1:-""}
run_mode=${2:-"interactive"} # Check for the second argument, default to interactive

if [ "$html_file" = "summary" ]; then
    generate_summary
    exit 0
fi

if [ -z "$html_file" ] || [ ! -f "$html_file" ]; then
    echo -e "\033[0;31mError: HTML file not found: $html_file\033[0m"
    echo "Usage: ./send_bulk_email.sh <html_file>"
    exit 1
fi

if [ ! -f "emaillist.txt" ]; then
    echo -e "\033[0;31mError: emaillist.txt not found!\033[0m"
    exit 1
fi

# If called with "relay", run automatically. Otherwise, show the interactive menu.
if [ "$run_mode" = "relay" ]; then
    echo -e "\033[0;36m🚀 Auto-Relay Mode Activated by Webhook\033[0m"
    # Use Ultra Speed Mode settings for automated relays
    BATCH_SIZE=10000
    BATCH_DELAY=0
    WORKER_COUNT=15
    MODE_NAME="ULTRA SPEED MODE"
    MODE_DESC="Maximum speed (bypasses spam filters with speed)"
    TEST_ENABLED="false"
    send_bulk_campaign "$html_file"
else
    echo -e "\033[0;34mDomain: $DOMAIN\033[0m"
    echo -e "\033[0;34mHTML file: $html_file\033[0m"
    send_bulk_campaign "$html_file"
fi
# --- End of Main Execution Logic ---
