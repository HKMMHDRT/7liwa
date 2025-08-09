# SIBOU3AZA Cloudflare Email Relay System

## 🚀 Overview

This system creates a seamless email relay using Cloudflare Email Routing and Google Cloud Shell. External emails sent to your Cloudflare domain are automatically forwarded to your mailing list while preserving the original sender information.

## 📋 System Architecture

```
External Sender → Cloudflare Email Routing → Cloudflare Worker → Google Cloud Shell Webhook → Email Verification → SIBOU3AZA Bulk Sender → Recipients
```

### Key Features
- ✅ **Transparent Email Relay**: Recipients see original sender information
- ✅ **Email Verification**: SPF, DKIM, DMARC validation
- ✅ **Bulk Distribution**: Integration with SIBOU3AZA system
- ✅ **Real-time Processing**: Instant email forwarding
- ✅ **Comprehensive Logging**: Full activity tracking
- ✅ **Web Preview Integration**: Uses Google Cloud Shell's built-in web preview

## 🛠️ Prerequisites

### Cloudflare Setup (Already Completed)
- ✅ Domain added to Cloudflare: `2canrescue.online`
- ✅ Email Routing enabled
- ✅ Destination address configured
- ✅ Email Worker created

### Google Cloud Shell Requirements
- Node.js (automatically installed by setup script)
- Postfix mail server (from existing SIBOU3AZA setup)
- Domain verification for sending emails

## 📦 Installation & Setup

### Step 1: Make Scripts Executable
```bash
chmod +x *.sh
```

### Step 2: Start the Cloudflare Relay System
```bash
./start_cloudflare_relay.sh
```

This script will:
- Install Node.js and dependencies
- Configure domain settings
- Set up email list
- Start the webhook server on port 8080
- Provide the webhook URL for Cloudflare Worker

### Step 3: Update Cloudflare Worker

1. **Get the Webhook URL**: The startup script will display your webhook URL:
   ```
   https://8080-cs-YOUR-PROJECT-ID-default.cs-YOUR-REGION.cloudshell.dev/webhook/email
   ```

2. **Update Worker Code**: 
   - Go to Cloudflare Dashboard → Workers & Pages
   - Edit your email worker
   - Replace the `webhookUrl` variable with your actual URL
   - Use the code from `cloudflare_worker_updated.js`

3. **Deploy the Worker**: Save and deploy the updated worker

### Step 4: Configure Email List
```bash
nano emaillist.txt
```
Add recipient email addresses (one per line):
```
user1@example.com
user2@example.com
admin@yourdomain.com
```

### Step 5: Test the System
1. Send an email to: `inbox@2canrescue.online`
2. Monitor the webhook server: `./monitor_cloudflare_relay.sh`
3. Check logs: `tail -f webhook_server.log`

## 🎛️ Management Commands

### Start/Stop System
```bash
# Start the relay system
./start_cloudflare_relay.sh

# Stop the relay system
./stop_cloudflare_relay.sh

# Force stop (if needed)
./stop_cloudflare_relay.sh force
```

### Monitoring
```bash
# Interactive monitoring dashboard
./monitor_cloudflare_relay.sh

# Simple status check
./monitor_cloudflare_relay.sh status

# Test webhook endpoint
./monitor_cloudflare_relay.sh test
```

### Logs
```bash
# View server logs
tail -f webhook_server.log

# View webhook activity logs
tail -f webhook_logs/webhook_$(date +%Y-%m-%d).log

# View all log files
ls -la webhook_logs/
```

## 📊 System Components

### Files Created
- `package.json` - Node.js dependencies
- `cloudflare_webhook_server.js` - Main webhook server
- `cloudflare_worker_updated.js` - Updated Cloudflare Worker code
- `start_cloudflare_relay.sh` - System startup script
- `stop_cloudflare_relay.sh` - System shutdown script
- `monitor_cloudflare_relay.sh` - Monitoring and status tools

### Directories Created
- `webhook_logs/` - Daily webhook activity logs
- `webhook_temp/` - Temporary email processing files
- `node_modules/` - Node.js dependencies

### Configuration Files
- `sibou3aza.conf` - Updated with Cloudflare relay settings
- `emaillist.txt` - Recipient email addresses
- `webhook_server.pid` - Server process ID (when running)

## 🔧 Configuration Options

### Email Validation Settings
The system validates incoming emails using:
- **SPF Records**: Sender Policy Framework validation
- **DKIM Signatures**: DomainKeys Identified Mail verification
- **DMARC Policy**: Domain-based Message Authentication
- **Content Validation**: Subject and sender address checks

### Scoring System
- SPF Pass: +30 points
- DKIM Present: +30 points
- DMARC Pass: +40 points
- Valid Sender: +10 points
- Valid Subject: +10 points

**Minimum Score**: 50 points (emails below this threshold are rejected)

### Bulk Sending Integration
The system integrates with your existing SIBOU3AZA bulk sender:
- Uses `send_bulk_email.sh` for distribution
- Preserves original email headers
- Maintains sender authenticity
- Supports HTML and plain text emails

## 🌐 Web Preview Setup

### Accessing Your Webhook
1. **Start the Server**: `./start_cloudflare_relay.sh`
2. **Open Web Preview**: Click "Web Preview" in Cloud Shell
3. **Select Port 8080**: Choose "Preview on port 8080"
4. **Copy URL**: Use the generated URL for Cloudflare Worker

### Webhook Endpoints
- `GET /` - System information and instructions
- `POST /webhook/email` - Main email processing endpoint
- `GET /health` - Health check and system status
- `GET /status` - Detailed status and recent activity

## 🔍 Troubleshooting

### Common Issues

#### 1. Webhook Server Won't Start
```bash
# Check if port is in use
lsof -i :8080

# Force stop existing processes
./stop_cloudflare_relay.sh force

# Restart the system
./start_cloudflare_relay.sh
```

#### 2. Emails Not Being Received
```bash
# Check Cloudflare Worker logs in dashboard
# Verify webhook URL is correct
# Test webhook endpoint
curl http://localhost:8080/health
```

#### 3. Email Validation Failing
```bash
# Check webhook logs
tail -f webhook_logs/webhook_$(date +%Y-%m-%d).log

# Monitor real-time activity
./monitor_cloudflare_relay.sh
```

#### 4. Bulk Sending Issues
```bash
# Verify email list exists
cat emaillist.txt

# Check SIBOU3AZA configuration
cat sibou3aza.conf

# Test bulk sender manually
./send_bulk_email.sh template.html
```

### Log Analysis

#### Server Logs (`webhook_server.log`)
- Server startup/shutdown events
- HTTP request/response information
- System errors and warnings

#### Webhook Logs (`webhook_logs/webhook_YYYY-MM-DD.log`)
- Email processing events
- Validation results
- Relay success/failure status
- Detailed error information

## 📈 Performance Monitoring

### Key Metrics
- **Request Rate**: Emails processed per minute
- **Success Rate**: Percentage of successfully relayed emails
- **Validation Score**: Average email validation scores
- **Processing Time**: Time taken to process each email

### Monitoring Dashboard
The interactive monitor (`./monitor_cloudflare_relay.sh`) provides:
- Real-time system status
- Recent activity logs
- Resource usage information
- Control commands for system management

## 🔒 Security Features

### Email Validation
- SPF record verification
- DKIM signature validation
- DMARC policy compliance
- Content-based spam detection

### System Security
- Request logging and monitoring
- Error handling and recovery
- Process isolation
- Secure webhook endpoints

## 🚀 Advanced Usage

### Custom Email Processing
You can modify `cloudflare_webhook_server.js` to add:
- Custom validation rules
- Content filtering
- Attachment processing
- Custom relay logic

### Integration with Other Systems
The webhook server can be extended to:
- Send notifications to Slack/Discord
- Store emails in databases
- Trigger custom workflows
- Generate analytics reports

## 📞 Support

### Getting Help
1. **Check Logs**: Always start with log analysis
2. **Use Monitor**: Interactive monitoring provides real-time insights
3. **Test Components**: Use individual test commands
4. **Review Configuration**: Verify all settings are correct

### Useful Commands
```bash
# Complete system status
./monitor_cloudflare_relay.sh status

# Test webhook connectivity
curl -X POST http://localhost:8080/webhook/email -d "test"

# Check email list
wc -l emaillist.txt

# Verify domain configuration
./verify_domain.sh yourdomain.com
```

## 🎯 Next Steps

After successful setup:
1. **Monitor Performance**: Use the monitoring dashboard regularly
2. **Optimize Email List**: Keep recipient list updated
3. **Review Logs**: Check for any validation issues
4. **Scale Up**: Add more recipients as needed
5. **Customize**: Modify validation rules based on your needs

---

**System Status**: Ready for production use
**Last Updated**: $(date)
**Version**: 1.0.0