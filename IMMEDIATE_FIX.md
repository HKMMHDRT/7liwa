# Immediate Fix for Webhook Server Issue

## Step 1: Fix Package Dependencies
```bash
cp package_fixed.json package.json
rm -rf node_modules
npm install
```

## Step 2: Debug the Issue
```bash
chmod +x debug_webhook.sh
./debug_webhook.sh
```

## Step 3: Check What's Wrong
```bash
cat webhook_server.log
```

## Step 4: Manual Server Start (Test)
```bash
node cloudflare_webhook_server.js
```
Press Ctrl+C to stop after testing.

## Step 5: Get Correct Webhook URL
```bash
./get_webhook_url.sh
```

## Step 6: Fix Postfix Warning
```bash
sudo ./fix_postfix_config.sh
```

## Step 7: Try Starting Again
```bash
./start_cloudflare_relay.sh
```

## If Still Failing - Alternative Start
```bash
# Start server manually in background
nohup node cloudflare_webhook_server.js > webhook_server.log 2>&1 &
echo $! > webhook_server.pid
```

## Check Status
```bash
ps aux | grep cloudflare_webhook_server
lsof -i :8080
curl http://localhost:8080/health
```

## Get Web Preview URL
1. Click "Web Preview" in Cloud Shell
2. Select "Preview on port 8080"
3. Copy the URL
4. Add `/webhook/email` to the end
5. Update Cloudflare Worker with this URL