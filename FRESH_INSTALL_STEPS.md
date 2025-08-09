# Fresh Install Steps - New Cloud Shell

## Step 1: Create Directory
```bash
mkdir SIBOU3AZA4
cd SIBOU3AZA4
```

## Step 2: Install System Packages
```bash
sudo apt-get update -y
sudo apt-get install postfix postfix-pcre opendkim opendkim-tools mailutils dnsutils tmux curl -y
```
When prompted:
- Select: `2. Internet Site`
- System mail name: `2CANRESCUE.ORG`

## Step 3: Install Node.js
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## Step 4: Create All Files
Copy all files from your project to this directory:
- package.json
- cloudflare_webhook_server.js
- cloudflare_worker_fixed.js
- start_cloudflare_relay.sh
- stop_cloudflare_relay.sh
- monitor_cloudflare_relay.sh
- get_webhook_url.sh
- fix_postfix_config.sh
- emaillist.txt
- setup_mailer.sh (from old setup)
- verify_domain.sh (from old setup)

## Step 5: Make Scripts Executable
```bash
chmod +x *.sh
```

## Step 6: Install Node Dependencies
```bash
npm install
```

## Step 7: Setup Domain and Mail
```bash
sudo ./setup_mailer.sh
```
Enter:
- Domain: `2canrescue.org`
- Hostname: `2canrescue.org`
- Sender email: `noreply@2canrescue.org`
- Sender name: `noreply`
- Email subject: (press Enter)
- Email list: `emaillist.txt`
- Forward email: `forward@2canrescue.org`

## Step 8: Add DNS Records
Add these DNS records to your domain:
```
Type: TXT, Name: @, Value: v=spf1 ip4:YOUR_IP include:_spf.google.com ~all
Type: TXT, Name: mail._domainkey, Value: (DKIM key from setup output)
Type: TXT, Name: _dmarc, Value: v=DMARC1; p=none; rua=mailto:dmarc@2canrescue.org; ruf=mailto:dmarc@2canrescue.org; fo=1
```

## Step 9: Verify DNS
```bash
./verify_domain.sh 2canrescue.org
```

## Step 10: Fix Postfix Config
```bash
sudo ./fix_postfix_config.sh
```

## Step 11: Start Services
```bash
sudo service postfix start
sudo service opendkim start
```

## Step 12: Get Webhook URL
```bash
./get_webhook_url.sh
```
Copy the webhook URL from output.

## Step 13: Update Cloudflare Worker
1. Go to https://dash.cloudflare.com
2. Workers & Pages → gcs-email-forwarder → Edit code
3. Delete all code
4. Copy code from `cloudflare_worker_fixed.js`
5. Replace line 11 with your webhook URL
6. Save and deploy

## Step 14: Start Webhook Server
```bash
./start_cloudflare_relay.sh
```

## Step 15: Test System
1. Send email to: `inbox@2canrescue.online`
2. Monitor: `tail -f webhook_server.log`
3. Check recipient inbox

## Troubleshooting Commands
```bash
./monitor_cloudflare_relay.sh status
ps aux | grep cloudflare_webhook_server
lsof -i :8080
sudo tail -f /var/log/mail.log