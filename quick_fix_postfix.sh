#!/bin/bash

# Quick Fix for Postfix Not Running
echo "🔧 SIBOU3AZA4 - Quick Postfix Fix"
echo "================================"
echo ""

# Check current status
echo "1. Checking current Postfix status..."
sudo service postfix status

echo ""
echo "2. Starting Postfix service..."
sudo service postfix start

echo ""
echo "3. Enabling Postfix to start automatically..."
sudo systemctl enable postfix

echo ""
echo "4. Checking if Postfix is now running..."
sudo service postfix status

echo ""
echo "5. Checking OpenDKIM as well..."
sudo service opendkim status || echo "OpenDKIM not running, starting..."
sudo service opendkim start
sudo systemctl enable opendkim

echo ""
echo "6. Final status check..."
echo "Postfix status:"
sudo service postfix status
echo ""
echo "OpenDKIM status:"
sudo service opendkim status

echo ""
echo "✅ Services should now be running!"
echo "Test with: ./send_bulk_email.sh template.html"
