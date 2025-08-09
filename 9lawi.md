
# SIBOU3AZA - The Definitive Command Reference

This document provides a comprehensive list of all commands for setting up and operating the SIBOU3AZA email relay system on a fresh Ubuntu server. It assumes the use of a DigitalOcean Droplet and Cloudflare.

## Part 1: Initial Server Setup (Run Once)

These commands prepare a new server and install all necessary components.

### 1.1. System Preparation
```bash
# Update all system packages
apt update && apt upgrade -y

# Install core software: mail server, DKIM, DNS tools, and curl
apt install -y postfix opendkim opendkim-tools mailutils dnsutils curl

# Install the correct version of Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### 1.2. Get Project Files
```bash
# Clone the project files from your Git repository
git clone https://github.com/HKMMHDRT/7liwa.git

# Enter the project directory
cd 7liwa
```

### 1.3. One-Time Configuration
```bash
# Make all shell scripts executable
chmod +x *.sh

# Install Node.js dependencies for the webhook server
npm install

# Run the primary setup script to configure your sending domain
# This will generate the DNS records you need for the next step.
sudo ./setup_mailer.sh
```

### 1.4. DNS Configuration in DigitalOcean
After running `setup_mailer.sh`, add the outputted records to your **sending domain's** DNS settings in the DigitalOcean control panel.

| Type  | Hostname          | Value                                       |
| :---- | :---------------- | :------------------------------------------ |
| A     | `@`               | Your Droplet's IP Address                   |
| MX    | `@`               | `your-sending-domain.com.` (dot at the end) |
| TXT   | `@`               | The `v=spf1...` value from the script output |
| TXT   | `mail._domainkey` | The `v=DKIM1...` value from the script output |
| TXT   | `_dmarc`          | The `v=DMARC1...` value from the script output|

### 1.5. Set the PTR Record (CRITICAL for Deliverability)
This is the most important step for not landing in spam.

1.  In your DigitalOcean control panel, go to your Droplet's **Networking** tab.
2.  Find the **PTR Records** section.
3.  Edit the record for your IP address and set the hostname to your **sending domain** (e.g., `your-sending-domain.com`).

---

## Part 2: System Operation

### 2.1. Starting the Relay System (Two-Terminal Process)

You need two separate terminal windows connected to your server.

**Terminal 1: Start the Webhook Server**
```bash
# Navigate to the project directory
cd /root/7liwa

# Start the Node.js server
node cloudflare_webhook_server.js
```
*Leave this terminal running. It listens for incoming emails from Cloudflare.*

**Terminal 2: Start the Secure Tunnel**
```bash
# Navigate to the project directory
cd /root/7liwa

# Install cloudflared if it's not already installed
# curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
# sudo dpkg -i cloudflared.deb

# Start the tunnel to expose your local webhook server to the internet
cloudflared tunnel --url http://localhost:8080
```
*Leave this terminal running. Copy the `.trycloudflare.com` URL it generates and paste it into your Cloudflare Worker that handles email for `2canrescue.online`.*

### 2.2. Stopping the System
*   Press `CTRL+C` in Terminal 1.
*   Press `CTRL+C` in Terminal 2.

---

## Part 3: Monitoring & Troubleshooting Commands

### 3.1. Real-Time Monitoring
```bash
# Watch the mail server logs for sending activity
sudo tail -f /var/log/mail.log

# Check the current mail queue for stuck emails
mailq
```

### 3.2. Checking Service Status
```bash
# Check the status of the Postfix mail server
sudo systemctl status postfix

# Check the status of the OpenDKIM service
sudo systemctl status opendkim
```

### 3.3. Restarting Services
```bash
# Restart Postfix (if it's having issues)
sudo systemctl restart postfix

# Restart OpenDKIM
sudo systemctl restart opendkim

# Restart both
sudo systemctl restart postfix opendkim
```

### 3.4. DNS & Deliverability Verification
```bash
# Verify all DNS records (SPF, DKIM, DMARC) for your sending domain
./verify_domain.sh your-sending-domain.com

# Check your PTR Record (Reverse DNS). The output should be your sending domain.
dig -x YOUR_DROPLET_IP_ADDRESS +short
```

### 3.5. Mail Queue Management
```bash
# Delete all emails currently stuck in the mail queue
sudo postsuper -d ALL

# Rerun the mail queue for any deferred messages
sudo postqueue -f
```

### 3.6. Fixing Postfix Configuration Warnings
If you see `overriding earlier entry: mailbox_size_limit=0` warnings, run this script to clean the configuration file.
```bash
sudo ./fix_postfix_config.sh
```

---

## Part 4: Emergency & Recovery

### 4.1. Emergency Stop
This script immediately kills all sending processes, stops the mail services, and clears the queue.
```bash
# Make the script executable (only need to do this once)
chmod +x emergency_stop.sh

# Run the emergency stop
sudo ./emergency_stop.sh
```

### 4.2. System Restoration
If files are accidentally deleted or the configuration is broken, this script will attempt to restore the mail system to a working state.
```bash
# Make the script executable (only need to do this once)
chmod +x restore_sibou3aza*.sh

# Run the latest restoration script
sudo ./restore_sibou3aza5.sh```