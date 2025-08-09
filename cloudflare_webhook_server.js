#!/usr/bin/env node

/**
 * SIBOU3AZA Cloudflare Email Webhook Server
 * Receives emails from Cloudflare Worker and processes them for relay
 * VERSION 2.0 - With "On Behalf Of" Fix for Deliverability
 */

const express = require('express');
const bodyParser = require('body-parser');
const { simpleParser } = require('mailparser');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const crypto = require('crypto');

// Configuration
const PORT = process.env.PORT || 8080;
const WEBHOOK_PATH = '/webhook/email';
const LOG_DIR = './webhook_logs';
const TEMP_DIR = './webhook_temp';

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m',
    purple: '\x1b[35m'
};

// Create Express app
const app = express();

// Middleware to capture raw body for email processing
app.use('/webhook', bodyParser.raw({ 
    type: '*/*', 
    limit: '50mb' 
}));

// Regular middleware for other routes
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Create necessary directories
function createDirectories() {
    [LOG_DIR, TEMP_DIR].forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
            console.log(`${colors.green}✓ Created directory: ${dir}${colors.reset}`);
        }
    });
}

// Logging function
function log(level, message, data = null) {
    const timestamp = new Date().toISOString();
    const logEntry = {
        timestamp,
        level,
        message,
        data
    };
    
    // Console output with colors
    const colorMap = {
        'INFO': colors.blue,
        'SUCCESS': colors.green,
        'WARNING': colors.yellow,
        'ERROR': colors.red,
        'DEBUG': colors.cyan
    };
    
    const color = colorMap[level] || colors.reset;
    console.log(`${color}[${timestamp}] [${level}] ${message}${colors.reset}`);
    if (data) {
        console.log(`${colors.cyan}Data:${colors.reset}`, JSON.stringify(data, null, 2));
    }
    
    // File logging
    const logFile = path.join(LOG_DIR, `webhook_${new Date().toISOString().split('T')[0]}.log`);
    fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
}

// Load SIBOU3AZA configuration
function loadConfig() {
    try {
        if (fs.existsSync('sibou3aza.conf')) {
            const configContent = fs.readFileSync('sibou3aza.conf', 'utf8');
            const config = {};
            
            configContent.split('\n').forEach(line => {
                const match = line.match(/^([^#=]+)=["']?([^"']*)["']?$/);
                if (match) {
                    config[match[1].trim()] = match[2].trim();
                }
            });
            
            log('INFO', 'SIBOU3AZA configuration loaded', { domain: config.DOMAIN });
            return config;
        }
    } catch (error) {
        log('WARNING', 'Could not load SIBOU3AZA config, using defaults', { error: error.message });
    }
    
    return {
        DOMAIN: 'example.com',
        SENDER_EMAIL: 'noreply@example.com',
        EMAIL_LIST: 'emaillist.txt'
    };
}

// Email validation functions
async function validateEmail(emailData) {
    const validation = {
        spf: false,
        dkim: false,
        dmarc: false,
        score: 0,
        reasons: []
    };
    
    try {
        if (emailData.headers && emailData.headers.get('received-spf')) {
            const spfResult = emailData.headers.get('received-spf').toLowerCase();
            validation.spf = spfResult.includes('pass');
            if (validation.spf) validation.score += 30;
            validation.reasons.push(`SPF: ${validation.spf ? 'PASS' : 'FAIL'}`);
        }
        if (emailData.headers && emailData.headers.get('dkim-signature')) {
            validation.dkim = true;
            validation.score += 30;
            validation.reasons.push('DKIM: Signature present');
        }
        if (emailData.headers && emailData.headers.get('authentication-results')) {
            const authResults = emailData.headers.get('authentication-results').toLowerCase();
            validation.dmarc = authResults.includes('dmarc=pass');
            if (validation.dmarc) validation.score += 40;
            validation.reasons.push(`DMARC: ${validation.dmarc ? 'PASS' : 'FAIL'}`);
        }
        if (emailData.from && emailData.from.length > 0) {
            validation.score += 10;
            validation.reasons.push('Valid sender address');
        }
        if (emailData.subject && emailData.subject.length > 0) {
            validation.score += 10;
            validation.reasons.push('Valid subject line');
        }
    } catch (error) {
        log('ERROR', 'Email validation error', { error: error.message });
        validation.reasons.push(`Validation error: ${error.message}`);
    }
    
    return validation;
}

// Process and relay email
async function processAndRelayEmail(emailData, config) {
    try {
        log('INFO', 'Processing email for relay', {
            from: emailData.from ? emailData.from.text : 'unknown',
            subject: emailData.subject,
            to: emailData.to ? emailData.to.text : 'unknown'
        });
        
        const validation = await validateEmail(emailData);
        log('INFO', 'Email validation completed', validation);
        
        if (validation.score < 50) {
            log('WARNING', 'Email failed validation threshold', { 
                score: validation.score, 
                reasons: validation.reasons 
            });
            return { success: false, reason: 'Failed validation', validation };
        }
        
        const emailId = crypto.randomUUID();
        const templatePath = path.join(TEMP_DIR, `relay_${emailId}.eml`);
        
        // --- START OF FIX: "On Behalf Of" Header Construction ---
        
        // Get original sender details. Provides a fallback if the name is missing.
        const originalSenderName = emailData.from.value[0].name || emailData.from.value[0].address.split('@')[0];
        const sendingDomain = config.DOMAIN || '2canrescue.org'; // Fallback to ensure it's never empty

        // 1. Create the HONEST "From" header. It uses YOUR sending address but includes the original sender's name.
        let emailContent = `From: "${originalSenderName} via ${sendingDomain}" <noreply@${sendingDomain}>\n`;
        
        // 2. Create the "Reply-To" header. This ensures when a user clicks "Reply", it goes to the original sender.
        emailContent += `Reply-To: ${emailData.from.text}\n`;
        
        // --- END OF FIX ---

        // Add the rest of the essential headers
        emailContent += `Subject: ${emailData.subject || 'No Subject'}\n`;
        emailContent += `Message-ID: <${emailId}@${sendingDomain}>\n`;
        emailContent += `Date: ${new Date().toUTCString()}\n`;
        emailContent += `MIME-Version: 1.0\n`;
        
        // Add content type and body
        if (emailData.html) {
            emailContent += `Content-Type: text/html; charset=UTF-8\n`;
            emailContent += `Content-Transfer-Encoding: 8bit\n\n`;
            emailContent += emailData.html;
        } else if (emailData.text) {
            emailContent += `Content-Type: text/plain; charset=UTF-8\n`;
            emailContent += `Content-Transfer-Encoding: 8bit\n\n`;
            emailContent += emailData.text;
        } else {
            emailContent += `Content-Type: text/plain; charset=UTF-8\n\n`;
            emailContent += 'No content available';
        }
        
        fs.writeFileSync(templatePath, emailContent);
        log('SUCCESS', 'Email template created with correct headers', { templatePath, emailId });
        
        if (!fs.existsSync(config.EMAIL_LIST)) {
            log('WARNING', 'Email list not found, creating sample', { emailList: config.EMAIL_LIST });
            fs.writeFileSync(config.EMAIL_LIST, '# Add recipient email addresses here\n# example@domain.com\n');
        }
        
        const relayCommand = `./send_bulk_email.sh "${templatePath}" relay`;
        
        return new Promise((resolve) => {
            exec(relayCommand, { cwd: process.cwd() }, (error, stdout, stderr) => {
                if (error) {
                    log('ERROR', 'Email relay failed', { error: error.message, stdout, stderr });
                    resolve({ success: false, reason: 'Relay command failed', error: error.message });
                } else {
                    log('SUCCESS', 'Email relayed successfully', { emailId, stdout: stdout.substring(0, 500) });
                    resolve({ success: true, emailId, validation });
                }
                
                try {
                    fs.unlinkSync(templatePath);
                } catch (cleanupError) {
                    log('WARNING', 'Could not clean up template file', { templatePath, error: cleanupError.message });
                }
            });
        });
        
    } catch (error) {
        log('ERROR', 'Email processing error', { error: error.message });
        return { success: false, reason: 'Processing error', error: error.message };
    }
}

// Main webhook endpoint
app.post(WEBHOOK_PATH, async (req, res) => {
    const startTime = Date.now();
    const requestId = crypto.randomUUID().substring(0, 8);
    
    log('INFO', `Webhook request received [${requestId}]`, {
        contentType: req.get('content-type'),
        contentLength: req.get('content-length'),
        userAgent: req.get('user-agent')
    });
    
    try {
        const rawEmail = req.body;
        if (!rawEmail || rawEmail.length === 0) {
            log('ERROR', `Empty email body received [${requestId}]`);
            return res.status(400).json({ success: false, error: 'Empty email body', requestId });
        }
        
        log('INFO', `Parsing email data [${requestId}]`, { bodySize: rawEmail.length });
        const emailData = await simpleParser(rawEmail);
        
        log('INFO', `Email parsed successfully [${requestId}]`, {
            from: emailData.from ? emailData.from.text : 'unknown',
            to: emailData.to ? emailData.to.text : 'unknown',
            subject: emailData.subject,
            hasHtml: !!emailData.html,
            hasText: !!emailData.text,
            attachments: emailData.attachments ? emailData.attachments.length : 0
        });
        
        const config = loadConfig();
        const relayResult = await processAndRelayEmail(emailData, config);
        const processingTime = Date.now() - startTime;
        
        if (relayResult.success) {
            log('SUCCESS', `Email processed and relayed [${requestId}]`, {
                processingTime: `${processingTime}ms`,
                emailId: relayResult.emailId,
                validation: relayResult.validation
            });
            res.status(200).json({ success: true, message: 'Email processed and relayed successfully', requestId, emailId: relayResult.emailId, processingTime, validation: relayResult.validation });
        } else {
            log('WARNING', `Email processing failed [${requestId}]`, { reason: relayResult.reason, processingTime: `${processingTime}ms` });
            res.status(422).json({ success: false, message: 'Email processing failed', reason: relayResult.reason, requestId, processingTime, validation: relayResult.validation });
        }
        
    } catch (error) {
        const processingTime = Date.now() - startTime;
        log('ERROR', `Webhook processing error [${requestId}]`, { error: error.message, stack: error.stack, processingTime: `${processingTime}ms` });
        res.status(500).json({ success: false, error: 'Internal server error', message: error.message, requestId, processingTime });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    const config = loadConfig();
    const health = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        config: {
            domain: config.DOMAIN,
            emailList: config.EMAIL_LIST,
            emailListExists: fs.existsSync(config.EMAIL_LIST)
        },
        directories: {
            logs: fs.existsSync(LOG_DIR),
            temp: fs.existsSync(TEMP_DIR)
        }
    };
    res.json(health);
});

// Status endpoint
app.get('/status', (req, res) => {
    try {
        const logFiles = fs.readdirSync(LOG_DIR).filter(f => f.endsWith('.log'));
        const recentLogs = [];
        if (logFiles.length > 0) {
            const latestLogFile = path.join(LOG_DIR, logFiles.sort().pop());
            const logContent = fs.readFileSync(latestLogFile, 'utf8');
            const logs = logContent.trim().split('\n').slice(-10);
            logs.forEach(line => { try { recentLogs.push(JSON.parse(line)); } catch (e) { /* skip */ } });
        }
        res.json({ server: 'Cloudflare Email Webhook', status: 'running', port: PORT, webhookPath: WEBHOOK_PATH, recentActivity: recentLogs });
    } catch (error) {
        res.status(500).json({ error: 'Could not retrieve status', message: error.message });
    }
});

// Root endpoint
app.get('/', (req, res) => {
    const config = loadConfig();
    res.json({
        service: 'SIBOU3AZA Cloudflare Email Webhook',
        version: '2.0.0',
        status: 'running',
        endpoints: {
            webhook: `${req.protocol}://${req.get('host')}${WEBHOOK_PATH}`,
            health: `${req.protocol}://${req.get('host')}/health`,
            status: `${req.protocol}://${req.get('host')}/status`
        },
        configuration: {
            domain: config.DOMAIN,
            emailList: config.EMAIL_LIST,
            port: PORT
        }
    });
});

// Start server
function startServer() {
    createDirectories();
    const server = app.listen(PORT, () => {
        console.log(`${colors.purple}================================${colors.reset}`);
        console.log(`${colors.purple}  SIBOU3AZA CLOUDFLARE WEBHOOK${colors.reset}`);
        console.log(`${colors.purple}================================${colors.reset}`);
        console.log(`${colors.green}✓ Server running on port ${PORT}${colors.reset}`);
        console.log(`${colors.blue}✓ Webhook endpoint: ${WEBHOOK_PATH}${colors.reset}`);
        console.log(`${colors.cyan}✓ Health check: /health${colors.reset}`);
        console.log(`${colors.cyan}✓ Status: /status${colors.reset}`);
        console.log(`${colors.yellow}✓ Logs directory: ${LOG_DIR}${colors.reset}`);
        console.log(`${colors.purple}================================${colors.reset}`);
        log('INFO', 'Cloudflare Email Webhook Server started', { port: PORT, webhookPath: WEBHOOK_PATH, pid: process.pid });
    });

    process.on('SIGTERM', () => {
        log('INFO', 'Received SIGTERM, shutting down gracefully');
        server.close(() => { log('INFO', 'Server closed'); process.exit(0); });
    });
    process.on('SIGINT', () => {
        log('INFO', 'Received SIGINT, shutting down gracefully');
        server.close(() => { log('INFO', 'Server closed'); process.exit(0); });
    });
}

// Start the server
if (require.main === module) {
    startServer();
}

module.exports = app;