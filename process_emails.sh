#!/bin/bash

# SIBOU3AZA Email Processor
# Processes received emails and forwards them to mailing list using bulk sender

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   SIBOU3AZA EMAIL PROCESSOR${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

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

# Create processing directories if they don't exist
mkdir -p "${PROCESSING_DIR}/processed" 2>/dev/null
mkdir -p "${PROCESSING_DIR}/templates" 2>/dev/null
mkdir -p "${PROCESSING_DIR}/logs" 2>/dev/null

# Function to extract email content
extract_email_content() {
    local email_file="$1"
    local output_dir="$2"
    local email_id=$(basename "$email_file")
    
    echo -e "${CYAN}Processing email: ${email_id}${NC}"
    
    # Extract headers
    local subject=$(grep -i "^Subject:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//')
    local from=$(grep -i "^From:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//')
    local date=$(grep -i "^Date:" "$email_file" | head -1 | cut -d' ' -f2- | tr -d '\r\n' | sed 's/^[[:space:]]*//')
    
    echo -e "${BLUE}  From: ${from}${NC}"
    echo -e "${BLUE}  Subject: ${subject}${NC}"
    echo -e "${BLUE}  Date: ${date}${NC}"
    
    # Create output files
    local template_file="${output_dir}/${email_id}_template.html"
    local info_file="${output_dir}/${email_id}_info.txt"
    
    # Extract email body (handle both HTML and plain text)
    local content_type=$(grep -i "content-type:" "$email_file" | head -1)
    local is_html=false
    local body_content=""
    
    if echo "$content_type" | grep -qi "text/html"; then
        is_html=true
        echo -e "${YELLOW}  Content type: HTML${NC}"
    else
        echo -e "${YELLOW}  Content type: Plain text${NC}"
    fi
    
    # Find where headers end and body begins
    local body_start=$(grep -n "^$" "$email_file" | head -1 | cut -d: -f1)
    if [ -n "$body_start" ]; then
        body_start=$((body_start + 1))
        
        # Extract body content
        if [ "$is_html" = true ]; then
            # For HTML emails, try to extract the HTML part
            body_content=$(tail -n +$body_start "$email_file" | sed '/^--.*$/,$d')
            
            # If it's multipart, find the HTML section
            if echo "$content_type" | grep -qi "multipart"; then
                local html_section=$(echo "$body_content" | sed -n '/Content-Type:.*text\/html/,/^--/p' | sed '$d')
                if [ -n "$html_section" ]; then
                    # Remove Content-Type header from the section
                    body_content=$(echo "$html_section" | sed '/^Content-Type:/d' | sed '/^Content-Transfer-Encoding:/d' | sed '/^$/d')
                fi
            fi
        else
            # For plain text, convert to HTML
            body_content=$(tail -n +$body_start "$email_file" | sed '/^--.*$/,$d')
        fi
    else
        echo -e "${RED}  Could not find email body${NC}"
        return 1
    fi
    
    # Clean up the body content
    body_content=$(echo "$body_content" | sed 's/\r$//' | sed '/^$/d')
    
    # Create HTML template
    if [ "$is_html" = true ]; then
        # If already HTML, use as-is but ensure proper structure
        cat > "$template_file" <<HTML_TEMPLATE
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${subject}</title>
</head>
<body>
${body_content}
</body>
</html>
HTML_TEMPLATE
    else
        # Convert plain text to HTML
        cat > "$template_file" <<TEXT_TEMPLATE
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${subject}</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 20px; }
        .email-content { background: #f9f9f9; padding: 20px; border-radius: 5px; }
        .original-info { font-size: 0.9em; color: #666; border-bottom: 1px solid #ddd; padding-bottom: 10px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="email-content">
        <div class="original-info">
            <strong>Forwarded from:</strong> ${from}<br>
            <strong>Original Subject:</strong> ${subject}<br>
            <strong>Date:</strong> ${date}
        </div>
        <div class="message-content">
            <pre style="white-space: pre-wrap; font-family: Arial, sans-serif;">${body_content}</pre>
        </div>
    </div>
</body>
</html>
TEXT_TEMPLATE
    fi
    
    # Create info file
    cat > "$info_file" <<INFO
Email ID: ${email_id}
From: ${from}
Subject: ${subject}
Date: ${date}
Content Type: $(if [ "$is_html" = true ]; then echo "HTML"; else echo "Plain Text"; fi)
Template File: ${template_file}
Processed: $(date)
Status: Ready for forwarding
INFO
    
    echo -e "${GREEN}  ✓ Template created: $(basename "$template_file")${NC}"
    echo "$template_file"
}

# Function to send email using bulk sender
send_to_mailing_list() {
    local template_file="$1"
    local email_info="$2"
    
    echo -e "${PURPLE}Forwarding to mailing list...${NC}"
    
    # Check if bulk sender exists
    if [ ! -f "send_bulk_email.sh" ]; then
        echo -e "${RED}Bulk email sender not found. Please ensure send_bulk_email.sh exists.${NC}"
        return 1
    fi
    
    # Check if email list exists
    if [ ! -f "$EMAIL_LIST" ]; then
        echo -e "${RED}Email list file not found: $EMAIL_LIST${NC}"
        echo -e "${YELLOW}Please create your email list file with subscriber addresses.${NC}"
        return 1
    fi
    
    # Get subscriber count
    local subscriber_count=$(grep -v "^#" "$EMAIL_LIST" | grep -v "^$" | wc -l)
    echo -e "${BLUE}Sending to ${subscriber_count} subscribers...${NC}"
    
    # Run bulk sender with NORMAL mode for forwarded emails
    echo -e "${YELLOW}Using NORMAL mode for reliable delivery...${NC}"
    
    # Set environment variable to force normal mode and avoid prompts
    export SPEED_MODE="1"  # Normal mode
    export BATCH_SIZE="2000"
    export WORKER_COUNT="4"
    export BATCH_DELAY="1"
    
    # Execute bulk sender
    if ./send_bulk_email.sh "$template_file"; then
        echo -e "${GREEN}✓ Email successfully forwarded to mailing list!${NC}"
        
        # Log the successful forwarding
        echo "$(date): Forwarded email from $(grep 'From:' "$email_info") to $subscriber_count subscribers" >> "${PROCESSING_DIR}/logs/forwarding.log"
        
        return 0
    else
        echo -e "${RED}✗ Failed to forward email to mailing list${NC}"
        
        # Log the failure
        echo "$(date): FAILED to forward email from $(grep 'From:' "$email_info")" >> "${PROCESSING_DIR}/logs/forwarding.log"
        
        return 1
    fi
}

# Function to process all new emails
process_new_emails() {
    local processed_count=0
    local failed_count=0
    
    echo -e "${CYAN}Scanning for new emails in: ${MAILBOX_PATH}/new${NC}"
    
    if [ ! -d "$MAILBOX_PATH/new" ]; then
        echo -e "${RED}New email directory not found: ${MAILBOX_PATH}/new${NC}"
        return 1
    fi
    
    # Process each new email
    for email_file in "$MAILBOX_PATH/new"/*; do
        if [ -f "$email_file" ]; then
            echo ""
            echo -e "${YELLOW}=== Processing New Email ===${NC}"
            
            # Extract and create template
            local template_file=$(extract_email_content "$email_file" "${PROCESSING_DIR}/templates")
            
            if [ -n "$template_file" ] && [ -f "$template_file" ]; then
                local info_file="${template_file%_template.html}_info.txt"
                
                # Forward to mailing list
                if send_to_mailing_list "$template_file" "$info_file"; then
                    processed_count=$((processed_count + 1))
                    
                    # Move email to processed folder
                    local processed_email="${PROCESSING_DIR}/processed/$(basename "$email_file")"
                    mv "$email_file" "$processed_email"
                    
                    # Also move to cur folder (mark as read)
                    local cur_email="${MAILBOX_PATH}/cur/$(basename "$email_file"):2,S"
                    cp "$processed_email" "$cur_email" 2>/dev/null || true
                    
                    echo -e "${GREEN}✓ Email processed and forwarded successfully${NC}"
                else
                    failed_count=$((failed_count + 1))
                    echo -e "${RED}✗ Failed to forward email${NC}"
                fi
            else
                failed_count=$((failed_count + 1))
                echo -e "${RED}✗ Failed to extract email content${NC}"
            fi
            
            echo -e "${YELLOW}=== End Processing ===${NC}"
        fi
    done
    
    # Summary
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   PROCESSING SUMMARY${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "${GREEN}Successfully processed: ${processed_count}${NC}"
    echo -e "${RED}Failed: ${failed_count}${NC}"
    echo -e "${BLUE}Total: $((processed_count + failed_count))${NC}"
    
    if [ $processed_count -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Processed templates saved in: ${PROCESSING_DIR}/templates${NC}"
        echo -e "${CYAN}Original emails saved in: ${PROCESSING_DIR}/processed${NC}"
        echo -e "${CYAN}Forwarding log: ${PROCESSING_DIR}/logs/forwarding.log${NC}"
    fi
    
    return $((failed_count))
}

# Function to show processing status
show_status() {
    echo -e "${CYAN}Email Processing Status:${NC}"
    
    # Count emails in different states
    local new_emails=$(find "$MAILBOX_PATH/new" -type f 2>/dev/null | wc -l)
    local processed_emails=$(find "${PROCESSING_DIR}/processed" -type f 2>/dev/null | wc -l)
    local templates=$(find "${PROCESSING_DIR}/templates" -name "*_template.html" 2>/dev/null | wc -l)
    
    echo -e "${BLUE}  New emails waiting: ${new_emails}${NC}"
    echo -e "${BLUE}  Processed emails: ${processed_emails}${NC}"
    echo -e "${BLUE}  Templates created: ${templates}${NC}"
    
    # Show recent forwarding activity
    if [ -f "${PROCESSING_DIR}/logs/forwarding.log" ]; then
        echo ""
        echo -e "${CYAN}Recent forwarding activity:${NC}"
        tail -5 "${PROCESSING_DIR}/logs/forwarding.log" | while read -r line; do
            if echo "$line" | grep -q "FAILED"; then
                echo -e "${RED}  $line${NC}"
            else
                echo -e "${GREEN}  $line${NC}"
            fi
        done
    fi
}

# Main execution
main() {
    case "${1:-}" in
        "status")
            show_status
            ;;
        "process")
            process_new_emails
            ;;
        *)
            echo -e "${YELLOW}Checking for new emails to process...${NC}"
            echo ""
            
            # First show current status
            show_status
            echo ""
            
            # Then process new emails
            if [ $(find "$MAILBOX_PATH/new" -type f 2>/dev/null | wc -l) -gt 0 ]; then
                echo -e "${CYAN}Found new emails to process!${NC}"
                echo ""
                process_new_emails
            else
                echo -e "${YELLOW}No new emails to process.${NC}"
                echo ""
                echo -e "${BLUE}To test the system:${NC}"
                echo -e "${CYAN}1. Send an email to: ${MAILBOX_EMAIL}${NC}"
                echo -e "${CYAN}2. Wait 1-2 minutes for delivery${NC}"
                echo -e "${CYAN}3. Run: ./check_mailbox.sh (to verify reception)${NC}"
                echo -e "${CYAN}4. Run: ./process_emails.sh (to forward to list)${NC}"
            fi
            ;;
    esac
}

# Execute main function
main "$@"
