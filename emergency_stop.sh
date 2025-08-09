#!/bin/bash

# SIBOU3AZA4 - Emergency Stop Script
# Kills all active sending and monitoring operations.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}================================${NC}"
echo -e "${RED}   SIBOU3AZA4 EMERGENCY STOP${NC}"
echo -e "${RED}================================${NC}"
echo ""

# 1. Kill the bulk sending script and its workers
echo -e "${YELLOW}Step 1: Stopping any running bulk email campaigns...${NC}"
if pgrep -f "send_bulk_email.sh" > /dev/null; then
    # Use a more aggressive pkill with SIGKILL (-9) to ensure immediate termination
    # of the script and any of its child processes (like xargs and sendmail workers).
    pkill -9 -f "send_bulk_email.sh"
    echo -e "${GREEN}✓ Force-killed 'send_bulk_email.sh' and all related worker processes.${NC}"
else
    echo -e "${YELLOW}No 'send_bulk_email.sh' process found running.${NC}"
fi
echo ""

# 2. Stop the mailbox monitor
echo -e "${YELLOW}Step 2: Stopping the mailbox monitor...${NC}"
if [ -f "./monitor_mailbox.sh" ]; then
    ./monitor_mailbox.sh stop
else
    echo -e "${YELLOW}Mailbox monitor script not found.${NC}"
fi
echo ""

# 3. Stop the Postfix mail server
echo -e "${YELLOW}Step 3: Stopping the Postfix mail server...${NC}"
if systemctl is-active --quiet postfix; then
    sudo service postfix stop
    echo -e "${GREEN}✓ Postfix service stopped.${NC}"
else
    echo -e "${YELLOW}Postfix service was not running.${NC}"
fi
echo ""

# 4. Clear the mail queue
echo -e "${YELLOW}Step 4: Clearing the Postfix mail queue...${NC}"
sudo postsuper -d ALL >/dev/null 2>&1
echo -e "${GREEN}✓ Postfix mail queue has been cleared.${NC}"
echo ""

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}   ALL OPERATIONS HALTED${NC}"
echo -e "${GREEN}================================${NC}"
