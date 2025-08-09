# Quick Fix Steps

## Step 1: Fix Postfix
```bash
sudo ./fix_postfix_config.sh
```

## Step 2: Get Webhook URL
```bash
./get_webhook_url.sh
```
Copy the webhook URL from output.

## Step 3: Update Cloudflare Worker
1. Go to https://dash.cloudflare.com
2. Click Workers & Pages
3. Click your `gcs-email-forwarder` worker
4. Click Edit code
5. Delete all existing code
6. Copy all code from `cloudflare_worker_fixed.js` file
7. Replace line 11 with your webhook URL from Step 2
8. Click Save and deploy

## Step 4: Restart Services
```bash
sudo service postfix restart
sudo service opendkim restart
```

## Step 5: Start Webhook Server
```bash
./start_cloudflare_relay.sh
```

## Step 6: Test System
1. Send email to: `inbox@2canrescue.online`
2. Run: `tail -f webhook_server.log`
3. Check `hakim.mhaidrat@gmail.com` inbox

## If Still Not Working

### Check Status
```bash
./monitor_cloudflare_relay.sh status
```

### Check Logs
```bash
tail -f webhook_server.log
tail -f webhook_logs/webhook_$(date +%Y-%m-%d).log
```

### Restart Everything
```bash
./stop_cloudflare_relay.sh
sudo service postfix stop
sudo service opendkim stop
sudo service postfix start
sudo service opendkim start
./start_cloudflare_relay.sh