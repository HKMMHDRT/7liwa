#!/bin/bash

# SIBOU3AZA3 - HTML Email Sender
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA3 HTML Email Sender${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Load configuration
if [ -f "sibou3aza.conf" ]; then
    source sibou3aza.conf
else
    echo -e "${RED}Error: Configuration file not found. Run setup first.${NC}"
    exit 1
fi

# Function to convert HTML to proper email format
convert_html_to_email() {
    local html_file="$1"
    local output_file="$2"
    local recipient="$3"
    
    # Extract title/subject from HTML
    local subject=$(grep -i "<title>" "$html_file" | sed 's/<[^>]*>//g' | tr -d '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    if [ -z "$subject" ]; then
        subject="Newsletter from $SENDER_NAME"
    fi
    
    # Create proper email with headers
    cat > "$output_file" <<EOF
From: $SENDER_NAME <$SENDER_EMAIL>
To: $recipient
Subject: $subject
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8
X-SIBOU3AZA3-Campaign: html-composer-$(date +%Y%m%d_%H%M%S)
X-SIBOU3AZA3-Recipient: $recipient
Date: $(date -R)

EOF
    
    # Add HTML content
    cat "$html_file" >> "$output_file"
}

# Function to send HTML email to mailing list
send_html_to_list() {
    local html_file="$1"
    
    if [ ! -f "$html_file" ]; then
        echo -e "${RED}Error: HTML file not found: $html_file${NC}"
        exit 1
    fi
    
    if [ ! -f "$EMAIL_LIST" ]; then
        echo -e "${RED}Error: Mailing list file not found: $EMAIL_LIST${NC}"
        echo -e "${YELLOW}Create it with: nano $EMAIL_LIST${NC}"
        exit 1
    fi
    
    # Count total emails
    local total_emails=$(grep -v "^#" "$EMAIL_LIST" | grep -v "^$" | wc -l)
    
    if [ $total_emails -eq 0 ]; then
        echo -e "${RED}Error: No valid emails found in $EMAIL_LIST${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}HTML Email: $html_file${NC}"
    echo -e "${BLUE}Mailing list: $EMAIL_LIST${NC}"
    echo -e "${BLUE}Total recipients: $total_emails${NC}"
    echo ""
    
    # Show preview of HTML email
    local subject=$(grep -i "<title>" "$html_file" | sed 's/<[^>]*>//g' | tr -d '\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    echo -e "${YELLOW}📧 Email Preview:${NC}"
    echo -e "${GREEN}Subject: $subject${NC}"
    echo -e "${GREEN}From: $SENDER_NAME <$SENDER_EMAIL>${NC}"
    echo -e "${GREEN}Type: HTML Email${NC}"
    echo ""
    
    # Ask for confirmation
    echo -e "${YELLOW}Send this HTML email to $total_emails recipients? (y/n):${NC}"
    read -r confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Send cancelled.${NC}"
        exit 0
    fi
    
    # Initialize tracking files
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local success_file="html_success_${timestamp}.txt"
    local failure_file="html_failures_${timestamp}.txt"
    local stats_file="html_stats_${timestamp}.txt"
    
    echo "SIBOU3AZA3 HTML Email Campaign Started: $(date)" > "$success_file"
    echo "SIBOU3AZA3 HTML Email Failures: $(date)" > "$failure_file"
    echo "SIBOU3AZA3 HTML Email Statistics: $(date)" > "$stats_file"
    
    local current_email=0
    local success_count=0
    local failure_count=0
    
    echo -e "${GREEN}Starting HTML email campaign...${NC}"
    echo ""
    
    # Main sending loop - INDEPENDENT EMAIL SENDING
    while IFS= read -r email; do
        # Skip empty lines and comments
        [[ -z "$email" || "$email" =~ ^#.* ]] && continue
        email=$(echo "$email" | tr -d '\r' | xargs)
        
        ((current_email++))
        echo ""
        echo -e "${BLUE}═══════════════════════════════════${NC}"
        echo -e "${YELLOW}Processing Email $current_email of $total_emails${NC}"
        echo -e "${GREEN}Recipient: $email${NC}"
        echo -e "${BLUE}═══════════════════════════════════${NC}"
        
        # Validate email format
        if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            # Create personalized HTML email for this specific recipient
            local temp_file="/tmp/html_email_${current_email}_$$.eml"
            
            echo -e "${YELLOW}📧 Creating personalized HTML email for: $email${NC}"
            
            # Convert HTML to proper email format for this recipient
            convert_html_to_email "$html_file" "$temp_file" "$email"
            
            echo -e "${BLUE}📤 Sending HTML email independently...${NC}"
            
            # Send email to this specific recipient
            if /usr/sbin/sendmail -t < "$temp_file" 2>/dev/null; then
                echo -e "${GREEN}✅ SUCCESS: HTML email sent to $email${NC}"
                echo "$(date): SUCCESS - $email (Email #$current_email)" >> "$success_file"
                ((success_count++))
                
                # Log individual success
                echo "[$(date)] HTML Email #$current_email sent successfully to: $email" >> "html_sends_$timestamp.log"
            else
                echo -e "${RED}❌ FAILED: Could not send HTML email to $email${NC}"
                echo "$(date): FAILED - $email (Email #$current_email) - Send failed" >> "$failure_file"
                ((failure_count++))
                
                # Log individual failure
                echo "[$(date)] HTML Email #$current_email FAILED to: $email" >> "html_sends_$timestamp.log"
            fi
            
            # Cleanup temp file
            rm -f "$temp_file"
            
            # Rate limiting between emails (independent sending)
            echo -e "${BLUE}⏳ Waiting 3 seconds before next email...${NC}"
            sleep 3
            
        else
            echo -e "${RED}❌ INVALID EMAIL FORMAT: $email${NC}"
            echo "$(date): INVALID - $email (Email #$current_email) - Invalid format" >> "$failure_file"
            ((failure_count++))
            
            # Log invalid email
            echo "[$(date)] HTML Email #$current_email INVALID FORMAT: $email" >> "html_sends_$timestamp.log"
        fi
        
        # Show running progress
        local remaining=$((total_emails - current_email))
        echo -e "${BLUE}📊 Progress: $current_email/$total_emails completed, $remaining remaining${NC}"
        echo -e "${GREEN}✅ Successful: $success_count${NC} | ${RED}❌ Failed: $failure_count${NC}"
        
        # Progress checkpoint every 5 emails
        if (( current_email % 5 == 0 )); then
            echo ""
            echo -e "${YELLOW}🔄 CHECKPOINT: $current_email HTML emails processed${NC}"
            echo -e "${BLUE}Success rate so far: $(( success_count * 100 / current_email ))%${NC}"
            echo ""
        fi
        
    done < "$EMAIL_LIST"
    
    # Final statistics
    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}   HTML EMAIL CAMPAIGN COMPLETED${NC}"
    echo -e "${GREEN}================================${NC}"
    echo -e "${BLUE}Total Processed: $current_email${NC}"
    echo -e "${GREEN}Successful: $success_count${NC}"
    echo -e "${RED}Failed: $failure_count${NC}"
    
    if [ $current_email -gt 0 ]; then
        local success_rate=$((success_count * 100 / current_email))
        echo -e "${BLUE}Success Rate: ${success_rate}%${NC}"
    fi
    
    # Write final statistics
    cat >> "$stats_file" << STATS

HTML Email Campaign Completed: $(date)
Email Source: $(basename "$html_file")
Total Processed: $current_email
Successful Deliveries: $success_count
Failed Deliveries: $failure_count
Success Rate: $([ $current_email -gt 0 ] && echo "$((success_count * 100 / current_email))%" || echo "N/A")
Domain: $DOMAIN
Sender: $SENDER_EMAIL
Email Type: HTML SIBOU3AZA3
STATS
    
    # Update main tracking files
    cat "$success_file" >> successdelivery.txt 2>/dev/null || true
    cat "$failure_file" >> faileddelivery.txt 2>/dev/null || true
    cat "$stats_file" >> deliverystats.txt 2>/dev/null || true
    
    echo ""
    echo -e "${YELLOW}Tracking files created:${NC}"
    echo -e "${BLUE}• $success_file - Successful HTML sends${NC}"
    echo -e "${BLUE}• $failure_file - Failed HTML sends${NC}"
    echo -e "${BLUE}• $stats_file - HTML campaign statistics${NC}"
}

# Main execution
html_file=${1:-""}

if [ -z "$html_file" ]; then
    echo -e "${RED}Usage: ./send_html_email.sh <html_file>${NC}"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "${GREEN}  ./send_html_email.sh composed_email.html${NC}"
    echo -e "${GREEN}  ./send_html_email.sh newsletter.html${NC}"
    echo ""
    echo -e "${YELLOW}To create HTML email: ./compose_email.sh${NC}"
    exit 1
fi

echo -e "${BLUE}Domain: $DOMAIN${NC}"
echo -e "${BLUE}Sender: $SENDER_EMAIL${NC}"
echo -e "${BLUE}HTML file: $html_file${NC}"
echo ""

send_html_to_list "$html_file"

echo ""
echo -e "${YELLOW}Commands:${NC}"
echo -e "${GREEN}• Compose HTML email: ./compose_email.sh${NC}"
echo -e "${GREEN}• Send HTML email: ./send_html_email.sh [html_file]${NC}"
echo -e "${GREEN}• Check inbox: ./check_inbox.sh${NC}"
echo -e "${GREEN}• Read emails: ./read_email.sh${NC}"
