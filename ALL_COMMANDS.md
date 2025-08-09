# SIBOU3AZA - All Commands Reference

This document provides a comprehensive list of all commands for the SIBOU3AZA email marketing suite, organized by workflow.

## 1. Initial Setup (Run Once)

### 1.1. System Preparation
```bash
# Update system packages
sudo apt-get update -y

# Install all required packages
sudo apt-get install postfix postfix-pcre opendkim opendkim-tools mailutils dnsutils tmux curl -y

# Make all scripts executable
chmod +x *.sh
```

### 1.2. Fresh Installation Setup
```bash
# Run initial setup (generates DNS records)
sudo ./setup_mailer.sh
```
*Follow the on-screen prompts. When asked for the mail configuration type, choose **"Internet Site"**.*

### 1.3. DNS Configuration
The `setup_mailer.sh` script will output three DNS records (SPF, DKIM, DMARC). You must add these to your domain's DNS settings.

- **SPF Record (TXT):**
    - **Host/Name:** `@`
    - **Value:** `v=spf1 ip4:YOUR_SERVER_IP ~all` (Use the IP of your server)

- **DKIM Record (TXT):**
    - **Host/Name:** `mail._domainkey`
    - **Value:** (Copy the long `v=DKIM1;...` value from the setup output)

- **DMARC Record (TXT):**
    - **Host/Name:** `_dmarc`
    - **Value:** `v=DMARC1; p=none; rua=mailto:dmarc-reports@yourdomain.com`

### 1.4. Verify DNS Setup
```bash
# Verify all DNS records for your domain
./verify_domain.sh yourdomain.com
```

## 2. Sending Bulk Emails

### 2.1. Prepare Your Files
- **`emaillist.txt`**: Add your subscriber emails to this file, one email per line.
- **`template.html`**: Create your HTML email content in this file. The `<title>` tag will be used as the email subject.

### 2.2. Run the Bulk Sender
```bash
# Send with speed mode selection menu
./send_bulk_email.sh template.html
```
You will be prompted to select a speed mode: **Normal**, **Ultra Speed**, or **Custom**.

## 3. Mailbox Setup (for Receiving Emails)

### 3.1. Run the Mailbox Setup Script
```bash
# This script configures a virtual mailbox.
sudo ./setup_mailbox.sh
```
*Follow the prompts to create your mailbox (e.g., `inbox@yourdomain.com`).*

### 3.2. Add MX Record
Add the following MX record to your domain's DNS settings:
- **Type:** `MX`
- **Host/Name:** `@` (or your domain)
- **Value:** `yourdomain.com` (or your server hostname)
- **Priority:** `10`

### 3.3. Check Mailbox Status
```bash
./check_mailbox.sh
```

## 4. Processing Received Emails

### 4.1. Manual Processing
```bash
# This script finds new emails in the mailbox, extracts the content, 
# and sends it to everyone in emaillist.txt.
./process_emails.sh
```

### 4.2. Automated Processing
```bash
# Start the monitor in the background
./monitor_mailbox.sh start

# Check its status
./monitor_mailbox.sh status

# Stop the monitor
./monitor_mailbox.sh stop
```

## 5. Manual Email Control

### 5.1. Check for New Emails
```bash
./check_inbox.sh
```

### 5.2. List Available Emails
```bash
./read_email.sh
```

### 5.3. Read a Specific Email
```bash
./read_email.sh 1
```

### 5.4. Send Email to Mailing List
```bash
./send_to_list.sh "/path/to/email/file"
```

## 6. System Monitoring

### 6.1. Real-Time Monitoring
```bash
# Watch mail logs in real-time
sudo tail -f /var/log/mail.log

# Check mail queue status
mailq

# Monitor system resources
htop
```

### 6.2. Campaign Analysis
```bash
# View campaign summaries
ls -la bulk_campaign_*_summary.txt

# Check worker logs
ls -la bulk_logs/
```

## 7. Troubleshooting & Maintenance

### 7.1. Service Management
```bash
# Check service status
sudo service postfix status
sudo service opendkim status

# Start essential services
sudo service postfix start
sudo service opendkim start

# Restart mail services
sudo service postfix restart
sudo service opendkim restart

# Quick fix if services not running
./quick_fix_postfix.sh
```

### 7.2. System Restoration
```bash
# If your system is broken or files are deleted
sudo ./restore_sibou3aza4.sh
```

### 7.3. Mail Queue Management
```bash
# Check mail queue
mailq

# Clear mail queue
sudo postsuper -d ALL
```

### 7.4. Diagnostic Commands
```bash
# Run comprehensive email delivery test
./test_email_delivery.sh

# Check Postfix configuration
sudo postconf -n

# Verify DKIM keys
sudo ls -la /etc/opendkim/keys/
```

## 8. Emergency Commands

### 8.1. Emergency Stop
```bash
# to kill everything operating
chmod +x emergency_stop.sh
sudo ./emergency_stop.sh
```

### 8.2. System Recovery
```bash
# Complete system restoration
sudo ./restore_sibou3aza4.sh

# Force restart all services
sudo systemctl restart postfix opendkim
```
