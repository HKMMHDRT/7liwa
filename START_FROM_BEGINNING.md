# Complete Email Relay Setup - Fresh Start

## Step 1: Setup System
```bash
mkdir SIBOU3AZA4
cd SIBOU3AZA4
sudo apt-get update -y
sudo apt-get install postfix postfix-pcre opendkim opendkim-tools mailutils dnsutils tmux curl nodejs npm -y
```
When prompted: Select "2. Internet Site", System mail name: "2CANRESCUE.ORG"

## Step 2: Create Files
Copy these files to your directory:
- package.json (use package_fixed.json version)
- cloudflare_webhook_server.js
- cloudflare_worker_corrected.js
- emaillist.txt

## Step 3: Install Dependencies
```bash
chmod +x *.sh
npm install
```

## Step 4: Setup Domain
```bash
sudo ./setup_mailer.sh
```
Enter: Domain: 2canrescue.org, Sender: noreply@2canrescue.org

## Step 5: Add DNS Records
Add the DNS records shown in setup output to your domain.

## Step 6: Verify DNS
```bash
./verify_domain.sh 2canrescue.org
```

## Step 7: Fix Postfix
```bash
sudo ./fix_postfix_config.sh
```

## Step 8: Start Services
```bash
sudo service postfix start
sudo service opendkim start
```

## Step 9: Start Webhook Server
```bash
node cloudflare_webhook_server.js
```
Keep this terminal open!

## Step 10: Update Cloudflare Worker
1. Go to https://dash.cloudflare.com
2. Workers & Pages → gcs-email-forwarder → Edit code
3. Delete all code
4. Copy code from cloudflare_worker_corrected.js
5. Save and deploy

## Step 11: Test
Send email to: nn@2canrescue.online
Check recipients: hakim.mhaidrat@gmail.com

## The Fix:
Your webhook URL had double "https://" - that's why it failed. The corrected worker fixes this.