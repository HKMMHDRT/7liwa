/**
 * Updated Cloudflare Worker for SIBOU3AZA Email Relay System
 * This worker receives emails and forwards them to Google Cloud Shell webhook
 */

export default {
  async email(message, env, ctx) {
    console.log('Email received by Cloudflare Worker');
    
    try {
      // The webhook URL for your Google Cloud Shell server
      // You'll need to update this with your actual Cloud Shell web preview URL
      const webhookUrl = "https://8080-cs-YOUR-PROJECT-ID-default.cs-YOUR-REGION.cloudshell.dev/webhook/email";
      
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
        // You might want to implement retry logic here
      }
      
    } catch (error) {
      console.error('Error in Cloudflare Worker:', error.message);
      console.error('Error stack:', error.stack);
      
      // You might want to send the error to a monitoring service
      // or implement fallback behavior here
    }
  },
};

/**
 * SETUP INSTRUCTIONS:
 * 
 * 1. Start your Google Cloud Shell webhook server:
 *    npm install
 *    npm start
 * 
 * 2. Get your Cloud Shell web preview URL:
 *    - Click the web preview button in Cloud Shell
 *    - Select "Preview on port 8080"
 *    - Copy the generated URL (looks like: https://8080-cs-xxx-default.cs-xxx.cloudshell.dev)
 * 
 * 3. Update the webhookUrl variable above with your actual URL:
 *    const webhookUrl = "https://YOUR-ACTUAL-URL/webhook/email";
 * 
 * 4. Deploy this updated worker code to Cloudflare:
 *    - Go to Cloudflare Dashboard > Workers & Pages
 *    - Edit your existing email worker
 *    - Replace the code with this updated version
 *    - Save and deploy
 * 
 * 5. Test the system:
 *    - Send an email to inbox@2canrescue.online
 *    - Check your webhook server logs
 *    - Verify the email gets relayed to your mailing list
 */