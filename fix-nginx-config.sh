#!/bin/bash

# Fix Nginx Configuration - Update proxy_pass from port 3000 to 5000

echo "=========================================="
echo "Nginx Configuration Fix"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Find nginx config file
NGINX_CONFIG=""
if [ -f "/etc/nginx/sites-available/default" ]; then
    NGINX_CONFIG="/etc/nginx/sites-available/default"
elif [ -f "/etc/nginx/nginx.conf" ]; then
    NGINX_CONFIG="/etc/nginx/nginx.conf"
elif [ -f "/etc/nginx/conf.d/default.conf" ]; then
    NGINX_CONFIG="/etc/nginx/conf.d/default.conf"
else
    print_error "Could not find nginx configuration file"
    echo "Please locate your nginx config file manually"
    exit 1
fi

print_ok "Found nginx config: $NGINX_CONFIG"

# Backup the config
BACKUP_FILE="${NGINX_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp "$NGINX_CONFIG" "$BACKUP_FILE"
print_ok "Backup created: $BACKUP_FILE"

# Check current configuration
echo ""
echo "Current configuration (checking for port 3000):"
sudo grep -n "proxy_pass.*3000" "$NGINX_CONFIG" || print_warning "No port 3000 found (may already be fixed)"

# Fix the configuration
echo ""
print_warning "Updating nginx configuration..."
print_warning "Changing all 'proxy_pass http://localhost:3000' to 'proxy_pass http://localhost:5000'"
print_warning "Changing all 'proxy_pass http://127.0.0.1:3000' to 'proxy_pass http://127.0.0.1:5000'"

# Use sed to replace port 3000 with 5000 in proxy_pass directives
sudo sed -i 's|proxy_pass http://localhost:3000|proxy_pass http://localhost:5000|g' "$NGINX_CONFIG"
sudo sed -i 's|proxy_pass http://127.0.0.1:3000|proxy_pass http://127.0.0.1:5000|g' "$NGINX_CONFIG"
sudo sed -i 's|proxy_pass http://127.0.0.1:3000/|proxy_pass http://127.0.0.1:5000/|g' "$NGINX_CONFIG"
sudo sed -i 's|proxy_pass http://localhost:3000/|proxy_pass http://localhost:5000/|g' "$NGINX_CONFIG"

# Verify changes
echo ""
echo "Updated configuration (checking for port 5000):"
sudo grep -n "proxy_pass.*5000" "$NGINX_CONFIG" || print_warning "No port 5000 found - check manually"

# Test nginx configuration
echo ""
print_warning "Testing nginx configuration..."
if sudo nginx -t; then
    print_ok "Nginx configuration is valid"
    
    echo ""
    print_warning "Reloading nginx..."
    if sudo systemctl reload nginx; then
        print_ok "Nginx reloaded successfully"
    else
        print_error "Failed to reload nginx"
        echo "Try: sudo systemctl restart nginx"
    fi
else
    print_error "Nginx configuration test failed!"
    echo ""
    echo "Restoring backup..."
    sudo cp "$BACKUP_FILE" "$NGINX_CONFIG"
    print_warning "Backup restored. Please fix configuration manually."
    exit 1
fi

echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="

# Wait a moment for nginx to reload
sleep 2

# Test the endpoint
echo "Testing /api/departments through nginx..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://transport.soliflexpackaging.com/api/departments 2>/dev/null || echo "000")

if [ "$RESPONSE" = "200" ]; then
    print_ok "SUCCESS! Nginx proxy is now working (HTTP 200)"
    echo ""
    echo "Test response:"
    curl -s https://transport.soliflexpackaging.com/api/departments | head -c 200
    echo ""
elif [ "$RESPONSE" = "502" ]; then
    print_error "Still getting 502 error"
    print_warning "Backend may not be running or nginx needs more time"
    echo "Check: pm2 list | grep soliflex-backend"
    echo "Check: curl http://localhost:5000/health"
elif [ "$RESPONSE" = "000" ]; then
    print_warning "Cannot test from this machine (may need to test from browser)"
else
    print_warning "Got HTTP $RESPONSE - check nginx logs"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Config file: $NGINX_CONFIG"
echo "Backup: $BACKUP_FILE"
echo ""
echo "To verify manually:"
echo "  1. Check config: sudo grep 'proxy_pass' $NGINX_CONFIG"
echo "  2. Test nginx: sudo nginx -t"
echo "  3. View logs: sudo tail -f /var/log/nginx/error.log"
echo "  4. Test endpoint: curl https://transport.soliflexpackaging.com/api/departments"
echo ""

