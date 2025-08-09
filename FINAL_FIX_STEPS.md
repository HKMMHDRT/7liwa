# Final Fix Steps - Port 8080 Issue

## Step 1: Kill Port 8080 Processes
```bash
chmod +x kill_port_8080.sh
./kill_port_8080.sh
```

## Step 2: Verify Port is Free
```bash
lsof -i :8080
```
Should show nothing.

## Step 3: Start Webhook Server
```bash
node cloudflare_webhook_server.js
```
Should show server starting successfully.

## Step 4: Test Server (New Terminal)
Open new terminal tab and run:
```bash
cd SIBOU3AZA4
curl http://localhost:8080/health
```

## Step 5: Get Web Preview URL
1. Click "Web Preview" button in Cloud Shell
2. Select "Preview on port 8080"
3. Copy the URL (should be like: `https://8080-cs-994417609600-default.cs-europe-west1-onse.cloudshell.dev`)

## Step 6: Update Cloudflare Worker
1. Go to https://dash.cloudflare.com
2. Workers & Pages → gcs-email-forwarder → Edit code
3. Replace line 11 with:
```javascript
const webhookUrl = "https://8080-cs-994417609600-default.cs-europe-west1-onse.cloudshell.dev/webhook/email";
```
4. Save and deploy

## Step 7: Test Complete System
1. Send email to: `inbox@2canrescue.online`
2. Check webhook server terminal for activity
3. Check `hakim.mhaidrat@gmail.com` inbox

## If Server Stops Working
```bash
./kill_port_8080.sh
node cloudflare_webhook_server.js
```

## Keep Server Running in Background
```bash
./kill_port_8080.sh
nohup node cloudflare_webhook_server.js > webhook_server.log 2>&1 &
echo $! > webhook_server.pid
```

## Check Server Status
```bash
ps aux | grep cloudflare_webhook_server
curl http://localhost:8080/health