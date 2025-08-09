# DigitalOcean Node.js Fix & Webhook Setup

## Problem: Node.js Version Too Old
Your error shows Node.js doesn't support `node:buffer` - you need Node.js 16+

## Step 1: Update Node.js
```bash
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version
```
Should show v18.x.x or higher

## Step 2: Clean Install Dependencies
```bash
rm -rf node_modules package-lock.json
npm install
```

## Step 3: Get Your DigitalOcean IP
```bash
curl ifconfig.me
```
Example output: `192.168.1.100`

## Step 4: Start Webhook Server
```bash
node cloudflare_webhook_server.js
```
Keep this terminal open!

## Step 5: Your Webhook URL
Your webhook URL is: `http://YOUR_IP:8080/webhook/email`

Example: `http://192.168.1.100:8080/webhook/email`

## Step 6: Update Cloudflare Worker
1. Go to https://dash.cloudflare.com
2. Workers & Pages → gcs-email-forwarder → Edit code
3. Replace line 11 with:
```javascript
const webhookUrl = "http://YOUR_ACTUAL_IP:8080/webhook/email";
```
4. Save and deploy

## Step 7: Test
1. Send email to: `nn@2canrescue.online`
2. Watch webhook server terminal for activity
3. Check recipient inboxes

## Key Differences for DigitalOcean:
- Use `http://` (not `https://`)
- Use your actual server IP address
- Port 8080 must be open (DigitalOcean allows this by default)