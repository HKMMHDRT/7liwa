# Debug Email Delivery Issue

## Step 1: Run Email Flow Debug
```bash
chmod +x debug_email_flow.sh
./debug_email_flow.sh
```

## Step 2: Check Cloudflare Worker Logs
1. Go to https://dash.cloudflare.com
2. Workers & Pages → gcs-email-forwarder
3. Click "Logs" tab
4. Look for recent activity and errors

## Step 3: Check Webhook Server Terminal
Look at Terminal 1 (where webhook server is running) for any activity when you sent the test email.

## Step 4: Test Webhook Manually
```bash
curl -X POST http://localhost:8080/webhook/email \
  -H "Content-Type: application/octet-stream" \
  -H "X-Cloudflare-Email-From: test@substack.com" \
  -H "X-Cloudflare-Email-To: nn@2canrescue.online" \
  -d "From: test@substack.com
To: nn@2canrescue.online
Subject: Manual Test Email

This is a manual test email."
```

## Step 5: Check Email List
```bash
cat emaillist.txt
```
Make sure it has valid email addresses.

## Step 6: Test Bulk Sender Directly
```bash
echo "<html><body><h1>Test Email</h1><p>This is a test.</p></body></html>" > test_template.html
./send_bulk_email.sh test_template.html
```

## Step 7: Check Mail Logs
```bash
sudo tail -f /var/log/mail.log
```

## Common Issues:

### Issue 1: Cloudflare Worker Not Reaching Webhook
- **Check**: Cloudflare Worker logs show webhook call failures
- **Fix**: Verify webhook URL in worker is correct

### Issue 2: Webhook Receiving But Not Processing
- **Check**: Webhook server logs show requests but no processing
- **Fix**: Check email parsing logic

### Issue 3: Bulk Sender Not Working
- **Check**: send_bulk_email.sh fails
- **Fix**: Check postfix configuration and email list

### Issue 4: Emails Sent But Not Delivered
- **Check**: Mail logs show sending but recipients don't receive
- **Fix**: Check SPF/DKIM records and recipient spam folders

## Quick Test Commands:
```bash
# Check webhook server status
curl http://localhost:8080/health

# Check if webhook receives data
curl -X POST http://localhost:8080/webhook/email -d "test"

# Check email list
wc -l emaillist.txt

# Check postfix
sudo service postfix status

# Check recent mail activity
sudo tail -20 /var/log/mail.log