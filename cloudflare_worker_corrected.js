/**
 * CORRECTED Cloudflare Worker for SIBOU3AZA Email Relay System
 * Fixed the double https:// issue
 */

export default {
  async email(message, env, ctx) {
    console.log('Email received by Cloudflare Worker');
    
    try {
      // FIXED: Removed double https://
      const webhookUrl = "https://8080-cs-994417609600-default.cs-europe-west1-onse.cloudshell.dev/webhook/email";
      
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