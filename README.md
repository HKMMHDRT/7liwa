
# SIBOU3AZA - The Final Setup & Command Guide

This is the definitive guide to setting up the SIBOU3AZA Email Relay system from a fresh Ubuntu 22.04 server. The final system is **fully automatic**: when an email is sent to your Cloudflare address, it is instantly relayed to your entire mailing list at maximum speed, preserving the original sender.

This guide is in two parts:
1.  **Part 1: The Fresh Installation Guide** - A step-by-step walkthrough to build the system from zero.
2.  **Part 2: The Complete Command Reference** - A comprehensive list of commands for operating and maintaining the system after setup.

---

## Part 1: The Fresh Installation Guide

### Step 1: Server Preparation & Software Installation
Log in to your new server as `root` and run these commands.

1.  **Update System Packages:**
    ```bash
    apt apt-get update
    ```
2.  **Install Core Software:** This installs Postfix, OpenDKIM, and other utilities.
    ```bash
    sudo apt install -y postfix opendkim opendkim-tools mailutils dnsutils curl
    ```
    *   During the Postfix installation, a pink screen will appear. Select **Internet Site** and press Enter.
    *   For **System mail name**, enter your domain (e.g., `2canrescue.org`) and press Enter.

3.  **Install Modern Node.js (Critical Fix):** The default Ubuntu version is too old. This step is mandatory.
    ```bash
    # Add the official repository for Node.js version 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    
    # Install Node.js v18
    sudo apt-get install -y nodejs
    
    # Verify the correct version is installed
    node -v 
    # The output MUST show v18.x.x or higher
    ```

### Step 2: Create Project Files
Here we will create all the necessary files in the `/root/7liwa` directory.

1.  **Create the Project Folder:**
    ```bash
    mkdir /root/7liwa
    cd /root/7liwa
    ```
2.  **Create `package.json`:** This file tells Node.js which libraries to install.
    ```bash
    nano package.json
    ```
    Paste this exact content:
    ```json
    {
      "name": "cloudflare-email-relay",
      "version": "1.0.0",
      "description": "Cloudflare Email Routing webhook server",
      "main": "cloudflare_webhook_server.js",
      "scripts": { "start": "node cloudflare_webhook_server.js" },
      "dependencies": { "express": "^4.18.2", "mailparser": "^3.6.5" }
    }
    ```
    Press `CTRL+X`, then `Y`, then `Enter` to save and exit.

3.  **Create `cloudflare_webhook_server.js`:** This is the core of your webhook server. The code below contains the fix to automatically call the sending script.
    ```bash
    nano cloudflare_webhook_server.js
    ```
    Paste this exact code:
    ```javascript
    #!/usr/bin/env node
    const express = require('express');
    const { simpleParser } = require('mailparser');
    const fs = require('fs');
    const path = require('path');
    const { exec } = require('child_process');
    const crypto = require('crypto');

    const PORT = process.env.PORT || 8080;
    const TEMP_DIR = './webhook_temp';

    const app = express();
    app.use('/webhook/email', express.raw({ type: '*/*', limit: '50mb' }));
    if (!fs.existsSync(TEMP_DIR)) fs.mkdirSync(TEMP_DIR, { recursive: true });

    async function processAndRelayEmail(emailData) {
        console.log(`[INFO] Processing relay for: ${emailData.subject}`);
        const emailId = crypto.randomUUID();
        const templatePath = path.join(TEMP_DIR, `relay_${emailId}.eml`);

        let emailContent = `From: ${emailData.from.text}\n`;
        emailContent += `Subject: ${emailData.subject || 'No Subject'}\n`;
        emailContent += `MIME-Version: 1.0\n`;
        if (emailData.html) {
            emailContent += `Content-Type: text/html; charset=UTF-8\n\n${emailData.html}`;
        } else {
            emailContent += `Content-Type: text/plain; charset=UTF-8\n\n${emailData.text}`;
        }
        fs.writeFileSync(templatePath, emailContent);
        
        // CRITICAL FIX: Calls the sender script with the "relay" argument for automatic, non-interactive execution.
        const relayCommand = `./send_bulk_email.sh "${templatePath}" relay`;

        return new Promise((resolve) => {
            exec(relayCommand, (error, stdout, stderr) => {
                if (error) {
                    console.error(`[ERROR] Relay command failed: ${stderr}`);
                    resolve({ success: false });
                } else {
                    console.log(`[SUCCESS] Relay command executed: ${stdout}`);
                    resolve({ success: true });
                }
                fs.unlinkSync(templatePath); // Clean up temp file
            });
        });
    }

    app.post('/webhook/email', async (req, res) => {
        try {
            const emailData = await simpleParser(req.body);
            const result = await processAndRelayEmail(emailData);
            res.status(result.success ? 200 : 500).json(result);
        } catch (error) {
            console.error(`[ERROR] Webhook processing error: ${error.message}`);
            res.status(500).json({ success: false, error: 'Internal server error' });
        }
    });

    app.get('/health', (req, res) => res.json({ status: 'healthy' }));

    app.listen(PORT, () => {
        console.log(`================================`);
        console.log(`  SIBOU3AZA WEBHOOK IS LIVE`);
        console.log(`================================`);
        console.log(`✓ Server running on port ${PORT}`);
    });
    ```
    Save and exit.

4.  **Create `send_bulk_email.sh`:** This is your powerful sending script. The code below contains the fix to run automatically when it receives the "relay" argument.
    ```bash
    nano send_bulk_email.sh
    ```
    Paste this exact code:
    ```bash
    #!/bin/bash
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

    send_bulk_campaign() {
        local html_file="$1"
        local clean_emails="bulk_temp/clean_emails.txt"
        mkdir -p bulk_temp

        grep -v "^#" "emaillist.txt" | tr -d '\r' > "$clean_emails"
        local total_emails=$(wc -l < "$clean_emails")
        echo -e "${YELLOW}Sending to $total_emails emails using $WORKER_COUNT workers...${NC}"

        local subject=$(grep -i "<title>" "$html_file" 2>/dev/null | sed -e 's/<[^>]*>//g' | head -1)
        [ -z "$subject" ] && subject=$(grep -i "Subject:" "$html_file" | cut -d' ' -f2-)
        local from_header=$(grep -i "From:" "$html_file" | head -1)
        [ -z "$from_header" ] && from_header="From: Relayed Email <noreply@2canrescue.org>"

        local master_template="bulk_temp/master_template.eml"
        {
            echo "$from_header"
            echo "Subject: $subject"
            echo "MIME-Version: 1.0"
            echo "Content-Type: text/html; charset=UTF-8"
            echo ""
            sed -e '1,/^$/d' "$html_file"
        } > "$master_template"
        
        cat "$clean_emails" | xargs -P $WORKER_COUNT -I {} bash -c \
        'email="{}"; (echo "To: $email"; cat bulk_temp/master_template.eml) | /usr/sbin/sendmail -t'

        echo -e "${GREEN}Campaign Complete! Sent $total_emails emails.${NC}"
        rm -rf bulk_temp
    }

    # --- MAIN EXECUTION LOGIC ---
    html_file=${1:-""}
    run_mode=${2:-"interactive"}

    if [ ! -f "$html_file" ]; then
        echo -e "${RED}Error: HTML file not found: $html_file${NC}"; exit 1;
    fi
    if [ ! -f "emaillist.txt" ]; then
        echo -e "${RED}Error: emaillist.txt not found!${NC}"; exit 1;
    fi

    if [ "$run_mode" = "relay" ]; then
        echo -e "${CYAN}🚀 Auto-Relay Mode Activated by Webhook${NC}"
        WORKER_COUNT=15 # Ultra Speed for relays
        send_bulk_campaign "$html_file"
    else
        echo -e "${BLUE}Starting Manual Campaign...${NC}"
        WORKER_COUNT=6 # Normal speed for manual campaigns
        send_bulk_campaign "$html_file"
    fi
    ```
    Save and exit.

5.  **Create your `emaillist.txt` file:**
    ```bash
    nano emaillist.txt
    ```
    Add your recipient emails (one per line):
    ```
    hakim.mhaidrat@gmail.com
    hakim.mhaidrat@yahoo.com
    ```
    Save and exit.

6.  **Make your script executable:**
    ```bash
    chmod +x send_bulk_email.sh
    ```

7.  **Install Node.js dependencies:**
    ```bash
    npm install
    ```

### Step 3: Configure Mail Server (Postfix & OpenDKIM)
This manual setup is more reliable than complex scripts.

1.  **Generate DKIM Keys:** (Replace `2canrescue.org` with your domain if different)
    ```bash
    sudo opendkim-genkey -s mail -d 2canrescue.org -D /etc/opendkim/
    sudo mv /etc/opendkim/mail.private /etc/opendkim/mail.private.key
    sudo mv /etc/opendkim/mail.txt /etc/opendkim/mail.key.txt
    sudo chown opendkim:opendkim /etc/opendkim/mail.private.key
    ```
2.  **Configure OpenDKIM (`opendkim.conf`):**
    ```bash
    sudo nano /etc/opendkim.conf
    ```
    Delete everything in the file and replace it with this (update the `Domain` if needed):
    ```
    Syslog          yes
    UMask           002
    Mode            sv
    KeyFile         /etc/opendkim/mail.private.key
    Selector        mail
    Domain          2canrescue.org
    Socket          inet:8891@localhost
    ```
    Save and exit.
3.  **Configure Postfix (`main.cf`):**
    ```bash
    sudo nano /etc/postfix/main.cf
    ```
    Go to the **very end** of the file and add these lines:
    ```
    # DKIM Milter Configuration
    milter_default_action = accept
    milter_protocol = 2
    smtpd_milters = inet:localhost:8891
    non_smtpd_milters = inet:localhost:8891
    ```
    Save and exit.
4.  **Restart and Enable Mail Services:**
    ```bash
    sudo systemctl restart postfix opendkim
    sudo systemctl enable postfix opendkim
    ```

### Step 4: Configure Cloudflare DNS
Log in to Cloudflare and go to the DNS settings for `2canrescue.org`.

| Type  | Name              | Content                                     | Proxy Status |
| :---- | :---------------- | :------------------------------------------ | :----------- |
| A     | `@`               | Your Droplet's IP Address                   | DNS Only     |
| MX    | `@`               | `2canrescue.org`                            | N/A          |
| TXT   | `@`               | `v=spf1 mx a ~all`                          | N/A          |
| TXT   | `mail._domainkey` | *(Paste the value from the command below)*  | N/A          |
| TXT   | `_dmarc`          | `v=DMARC1; p=none;`                         | N/A          |

To get the value for your **DKIM record**, run this command on your server and copy the entire output:
```bash
cat /etc/opendkim/mail.key.txt
```

### Step 5: Configure Cloudflare Worker
1.  In Cloudflare, go to **Email** -> **Email Routing**.
2.  Click the **Routes** tab, then **Create address**.
    *   **Custom address:** `bbhbi` (or another name)
    *   **Action:** `Send to a Worker`
    *   **Destination:** Select or create a Worker (e.g., `email-relay-worker`).
3.  Navigate to the Worker and click **Edit code**. Paste this Javascript inside:
    ```javascript
    export default {
      async email(message, env, ctx) {
        // This is a placeholder that you will replace in the final step.
        const webhookUrl = "https://YOUR_TUNNEL_URL_HERE/webhook/email";
        try {
          await fetch(webhookUrl, {
            method: "POST",
            headers: { 'Content-Type': 'application/octet-stream' },
            body: message.raw,
          });
        } catch (error) {
          console.error('Worker Error:', error.message);
        }
      }
    };
    ```
4.  Click **Save and Deploy**.

### Step 6: Go Live!
You need **two** separate SSH terminal windows.

1.  **In Terminal 1**, start the webhook server:
    ```bash
    cd /root/7liwa
    node cloudflare_webhook_server.js
    ```
    (Leave this running forever).

2.  **In Terminal 2**, install and start the secure Cloudflare Tunnel:
    ```bash
    # Download and install the tunnel software (only needs to be done once)
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared.deb

    # Start the tunnel to expose your server securely
    cloudflared tunnel --url http://localhost:8080
    ```
3.  The tunnel will output a URL ending in `.trycloudflare.com`. **Copy this URL.**

### Step 7: Final Worker Update
1.  Go back to the Cloudflare Worker editor.
2.  Replace the placeholder `https://YOUR_TUNNEL_URL_HERE` with the actual `.trycloudflare.com` URL you just copied.
3.  Click **Save and Deploy**.

**SETUP IS COMPLETE.** The system is now fully live and automated. Send an email to `bbhbi@2canrescue.online` to test it.

---

## Part 2: The Complete Command Reference

### Daily Operation
*   **Start the System:**
    ```bash
    # In Terminal 1 (run and leave open):
    cd /root/7liwa && node cloudflare_webhook_server.js

    # In Terminal 2 (run and leave open):
    cd /root/7liwa && cloudflared tunnel --url http://localhost:8080
    ```
*   **Stop the System:** Press `CTRL+C` in both terminal windows.

### System Monitoring
*   **Watch Webhook Activity:** In the `node` terminal, watch for new requests.
*   **Watch Real-time Mail Logs:**
    ```bash
    sudo tail -f /var/log/mail.log
    ```
*   **Check Mail Queue:** See if any emails are stuck.
    ```bash
    mailq
    ```
*   **Monitor System Resources:**
    ```bash
    htop
    ```

### Manual Sending (Optional)
If you want to send a marketing campaign *without* using the relay, you can still do so.
1.  Create an HTML file (e.g., `newsletter.html`).
2.  Run the manual sender:
    ```bash
    # This will send newsletter.html to everyone in emaillist.txt
    ./send_bulk_email.sh newsletter.html
    ```

### Maintenance & Troubleshooting
*   **Check Service Status:**
    ```bash
    sudo systemctl status postfix
    sudo systemctl status opendkim
    ```
*   **Restart Mail Services:**
    ```bash
    sudo systemctl restart postfix opendkim
    ```
*   **Clear the Mail Queue (if emails are stuck):**
    ```bash
    sudo postsuper -d ALL
    ```
*   **Check Postfix Configuration:**
    ```bash
    sudo postconf -n
    ```

### Emergency Stop
This script will immediately kill all sending processes and clear the mail queue. Create it for emergencies.
1.  `nano emergency_stop.sh`
2.  Paste the code below:
    ```bash
    #!/bin/bash
    echo "--- EMERGENCY STOP INITIATED ---"
    # Kill node server and cloudflare tunnel
    pkill -f "node cloudflare_webhook_server.js"
    pkill -f "cloudflared"
    # Stop mail service
    sudo service postfix stop
    # Clear all emails from the queue
    sudo postsuper -d ALL
    echo "--- ALL OPERATIONS HALTED ---"
    ```
3.  Make it executable: `chmod +x emergency_stop.sh`

4.  Run it when needed: `sudo ./emergency_stop.sh`
