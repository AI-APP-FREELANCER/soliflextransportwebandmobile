#!/bin/bash

# PM2 Recovery Script - Restore All Applications
# Run this on your VM to restore all PM2 processes

set -e

echo "=========================================="
echo "PM2 Recovery Script"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Check current PM2 status
print_status "Checking current PM2 status..."
pm2 list

echo ""
print_status "Attempting to restore saved PM2 processes..."
if pm2 resurrect 2>/dev/null; then
    print_status "✓ Restored processes from saved configuration"
else
    print_warning "No saved configuration found or restore failed"
    print_status "Will start applications manually..."
fi

echo ""
print_status "Searching for ecosystem.config.js files..."
ECOSYSTEM_FILES=$(find ~ -name "ecosystem.config.js" 2>/dev/null | grep -v node_modules)

if [ -z "$ECOSYSTEM_FILES" ]; then
    print_warning "No ecosystem.config.js files found"
else
    echo "Found ecosystem files:"
    echo "$ECOSYSTEM_FILES"
fi

echo ""
print_status "Starting known applications..."

# Soliflex Transport Application
if [ -d ~/transport/transportwebandmobile/soliflexweb ]; then
    print_status "Starting Soliflex Transport application..."
    cd ~/transport/transportwebandmobile/soliflexweb
    if [ -f "ecosystem.config.js" ]; then
        # Check if already running
        if pm2 list | grep -q "soliflex-backend\|soliflex-frontend"; then
            print_warning "Soliflex processes already exist, restarting..."
            pm2 restart ecosystem.config.js 2>/dev/null || pm2 start ecosystem.config.js
        else
            pm2 start ecosystem.config.js
        fi
        print_status "✓ Soliflex Transport started"
    else
        print_warning "ecosystem.config.js not found in Soliflex directory"
    fi
else
    print_warning "Soliflex Transport directory not found"
fi

# Check for other common application locations
# Add your other application paths here
# Example:
# if [ -d ~/other-app ]; then
#     print_status "Starting Other Application..."
#     cd ~/other-app
#     if [ -f "ecosystem.config.js" ]; then
#         pm2 start ecosystem.config.js
#         print_status "✓ Other Application started"
#     fi
# fi

echo ""
print_status "Saving PM2 configuration..."
pm2 save

echo ""
print_status "Waiting for processes to start..."
sleep 3

echo ""
print_status "Final PM2 Status:"
pm2 list

echo ""
print_status "Checking running ports..."
sudo netstat -tulpn | grep LISTEN | grep -E ":(3000|4000|5000|8081)" || print_warning "No processes found on common ports"

echo ""
echo "=========================================="
print_status "Recovery Complete!"
echo "=========================================="
echo ""
echo "Useful commands:"
echo "  pm2 list              - View all processes"
echo "  pm2 logs               - View all logs"
echo "  pm2 logs <app-name>    - View specific app logs"
echo "  pm2 monit              - Monitor resources"
echo "  pm2 restart all        - Restart all apps"
echo ""
echo "To find your other application:"
echo "  find ~ -name 'ecosystem.config.js' 2>/dev/null"
echo "  find ~ -name 'package.json' 2>/dev/null | grep -v node_modules"
echo ""

