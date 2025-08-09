/**
 * Fixed Cloudflare Worker for SIBOU3AZA Email Relay System
 * This worker receives emails and forwards them to Google Cloud Shell webhook
 */

export default {
  async email(message, env, ctx) {
    console.log('Email received by Cloudflare Worker');
    
    try {
      // The webhook URL for your Google Cloud Shell server
      // Update this with your actual Cloud Shell web preview URL
      const webhookUrl = "https://8080-cs-994417609600-default.europe-west1-c.c.t71947723978b23cc-tp.cloudshell.dev/webhook/email";
      
      // Log email details for debugging
      console.log('Email details:', {
        from: message.from,
        to: message.to,
        subject: message.headers.get('subject'),
        messageId: message.headers.get('message-id')
      });
      
      // Create headers object for the webhook request
      const webhookHeaders = new Headers();
      webhookHeaders.set('Content-Type', 'application/octet-stream');
      webhookHeaders.set('User-Agent', 'Cloudflare-Email-Worker/1.0');
      webhookHeaders.set('X-Cloudflare-Email-From', message.from);
      webhookHeaders.set('X-Cloudflare-Email-To', message.to);
      
      // Add original email headers as custom headers
      for (const [key, value] of message.headers) {
        webhookHeaders.set(`X-Original-${key}`, value);
      }
      
      // Forward the raw email content to the webhook
      const response = await fetch(webhookUrl, {
        method: "POST",
        headers: webhookHeaders,
        body: message.raw, // Forward the raw email stream
      });
      
      // Log the response from webhook
      const responseText = await response.text();
      console.log('Webhook response:', {
        status: response.status,
        statusText: response.statusText,
        body: responseText.substring(0, 500) // Log first 500 chars
      });
      
      if (response.ok) {
        console.log('Email successfully forwarded to webhook');
      } else {
        console.error('Webhook request failed:', response.status, responseText);
      }
      
    } catch (error) {
      console.error('Error in Cloudflare Worker:', error.message);
      console.error('Error stack:', error.stack);
    }
  },

  // Add fetch handler to prevent "No fetch handler!" error
  async fetch(request, env, ctx) {
    return new Response('Cloudflare Email Worker is running. This worker handles email routing only.', {
      status: 200,
      headers: {
        'Content-Type': 'text/plain',
      },
    });
  },
};

/**
 * UPDATED SETUP INSTRUCTIONS:
 * 
 * 1. Get your actual Cloud Shell web preview URL:
 *    - In Cloud Shell, run: echo "https://8080-cs-$(gcloud config get-value project)-default.$(gcloud config get-value compute/region).cloudshell.dev/webhook/email"
 *    - Or click "Web Preview" > "Preview on port 8080" and copy the URL
 * 
 * 2. Update the webhookUrl variable above with your actual URL
 * 
 * 3. Deploy this fixed worker code to Cloudflare:
 *    - Go to Cloudflare Dashboard > Workers & Pages
 *    - Edit your existing email worker
 *    - Replace ALL the code with this fixed version
 *    - Save and deploy
 * 
 * 4. Test the system:
 *    - Send an email to any address @2canrescue.online
 *    - Check your webhook server logs: tail -f webhook_server.log
 *    - Verify the email gets relayed to your mailing list
 */