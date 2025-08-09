# 🔧 SIBOU3AZA Cloudflare Relay Troubleshooting Guide

## 🚨 Quick Fixes for Common Issues

### Issue 1: "No fetch handler!" Error in Cloudflare Worker

**Problem**: Cloudflare Worker shows "No fetch handler!" error
**Solution**: Use the fixed worker code

```bash
# Use the fixed worker code from:
cat cloudflare_worker_fixed.js
```

**Steps**:
1. Go to Cloudflare Dashboard → Workers & Pages
2. Edit your `gcs-email-forwarder` worker
3. Replace ALL code with content from `cloudflare_worker_fixed.js`
4. Update the `webhookUrl` with your actual URL
5. Save and Deploy

### Issue 2: Empty Email List (0 addresses)

**Problem**: `emaillist.txt` has no recipients
**Solution**: Add recipient email addresses

```bash
# Edit the email list
nano emaillist.txt

# Add recipients (one per line):
hakim.mhaidrat@gmail.com
user2@example.com
admin@yourdomain.com
```

### Issue 3: Postfix Configuration Warnings

**Problem**: "overriding earlier entry: mailbox_size_limit=0"
**Solution**: Run the fix script

```bash
sudo ./fix_postfix_config.sh
```

### Issue 4: Incorrect Webhook URL

**Problem**: Webhook URL has empty project ID/region
**Solution**: Get the correct URL

```bash
# Run the URL generator
./get_webhook_url.sh

# Or manually get it:
echo "https://8080-cs-$(gcloud config get-value project)-default.$(gcloud config get-value compute/region).c.$(gcloud config get-value project).cloudshell.dev/webhook/email"
```

## 🔍 Step-by-Step Debugging

### Step 1: Verify System Status

```bash
# Check webhook server
./monitor_cloudflare_relay.sh status

# Check if server is running
ps aux | grep cloudflare_webhook_server

# Check port 8080
lsof -i :8080
```

### Step 2: Check Email List

```bash
# Verify email list has recipients
cat emaillist.txt | grep -v "^#" | grep -v "^$"

# Count recipients
wc -l emaillist.txt
```

### Step 3: Test Webhook Endpoint

```bash
# Test webhook locally
curl -X POST http://localhost:8080/health

# Test webhook with sample data
curl -X POST http://localhost:8080/webhook/email -d "test email data"
```

### Step 4: Check Logs

```bash
# View server logs
tail -f webhook_server.log

# View webhook activity logs
tail -f webhook_logs/webhook_$(date +%Y-%m-%d).log

# Check postfix logs
sudo tail -f /var/log/mail.log
```

### Step 5: Verify Cloudflare Configuration

1. **Check Email Routing**: Go to Cloudflare Dashboard → Email → Email Routing
2. **Verify Custom Address**: Ensure `inbox@2canrescue.online` routes to your worker
3. **Check Worker**: Verify worker is deployed and active
4. **Test Worker**: Send test email to trigger worker

## 🛠️ Complete System Reset

If everything fails, follow these steps for a complete reset:

### 1. Stop Everything
```bash
./stop_cloudflare_relay.sh force
sudo service postfix stop
sudo service opendkim stop
```

### 2. Fix Configuration
```bash
sudo ./fix_postfix_config.sh
```

### 3. Update Email List
```bash
nano emaillist.txt
# Add your recipient addresses
```

### 4. Get Correct Webhook URL
```bash
./get_webhook_url.sh
# Copy the generated URL
```

### 5. Update Cloudflare Worker
```bash
# Use the code from cloudflare_worker_fixed.js
# Update the webhookUrl with your actual URL
```

### 6. Restart Services
```bash
sudo service postfix start
sudo service opendkim start
```

### 7. Start Webhook Server
```bash
./start_cloudflare_relay.sh
```

### 8. Test the System
```bash
# Send test email to: inbox@2canrescue.online
# Monitor logs: tail -f webhook_server.log
```

## 📊 Verification Checklist

### ✅ Pre-Flight Checklist

- [ ] **Postfix Running**: `sudo service postfix status`
- [ ] **OpenDKIM Running**: `sudo service opendkim status`
- [ ] **Webhook Server Running**: `ps aux | grep cloudflare_webhook_server`
- [ ] **Port 8080 Open**: `lsof -i :8080`
- [ ] **Email List Has Recipients**: `wc -l emaillist.txt`
- [ ] **DNS Records Configured**: `./verify_domain.sh 2canrescue.org`
- [ ] **Cloudflare Worker Updated**: Check worker code has correct webhook URL
- [ ] **Email Routing Active**: Cloudflare dashboard shows routing is active

### ✅ Test Flow Checklist

- [ ] **Send Test Email**: Send email to `inbox@2canrescue.online`
- [ ] **Worker Receives Email**: Check Cloudflare worker logs
- [ ] **Webhook Gets Request**: Check `webhook_server.log`
- [ ] **Email Parsed Successfully**: Look for parsing success in logs
- [ ] **Validation Passes**: Check validation scores in logs
- [ ] **Bulk Sender Triggered**: Look for bulk sending activity
- [ ] **Recipients Receive Email**: Check recipient inboxes

## 🔧 Advanced Debugging

### Debug Webhook Server
```bash
# Start server in debug mode
DEBUG=* node cloudflare_webhook_server.js

# Check server health
curl http://localhost:8080/health | jq

# Check server status
curl http://localhost:8080/status | jq
```

### Debug Email Processing
```bash
# Monitor real-time processing
./monitor_cloudflare_relay.sh

# Check email validation
grep "validation" webhook_logs/webhook_$(date +%Y-%m-%d).log

# Check bulk sending
grep "bulk" webhook_server.log
```

### Debug Cloudflare Worker
1. Go to Cloudflare Dashboard → Workers & Pages
2. Click on your worker → Logs
3. Send test email and watch real-time logs
4. Look for errors or failed webhook calls

## 📞 Getting Help

### Log Collection for Support
```bash
# Collect all relevant logs
mkdir debug_logs
cp webhook_server.log debug_logs/
cp webhook_logs/* debug_logs/ 2>/dev/null || true
cp sibou3aza.conf debug_logs/
sudo cp /var/log/mail.log debug_logs/ 2>/dev/null || true

# Create system info
./monitor_cloudflare_relay.sh status > debug_logs/system_status.txt

# Package for sharing
tar -czf debug_logs.tar.gz debug_logs/
```

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "No fetch handler!" | Worker missing fetch handler | Use `cloudflare_worker_fixed.js` |
| "Empty email body" | Worker not sending data | Check worker webhook URL |
| "Email list not found" | Missing emaillist.txt | Create and populate email list |
| "Failed validation" | Email doesn't pass checks | Check SPF/DKIM/DMARC |
| "Bulk sender failed" | SIBOU3AZA system issue | Check postfix configuration |

## 🎯 Success Indicators

When everything is working correctly, you should see:

1. **Cloudflare Worker Logs**: "Email successfully forwarded to webhook"
2. **Webhook Server Logs**: "Email processed and relayed successfully"
3. **Bulk Sender Activity**: SIBOU3AZA bulk sending process starts
4. **Recipient Delivery**: Recipients receive email with original sender info

---

**Remember**: The goal is for recipients to see emails as coming from the original sender (e.g., `signalhunter@substack.com`) but sent through your authenticated domain (`2canrescue.org`).