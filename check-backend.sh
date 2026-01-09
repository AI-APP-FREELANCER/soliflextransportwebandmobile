#!/bin/bash

# Quick Backend and Nginx Diagnostic Script
# Run this to check if backend is running and accessible

echo "=========================================="
echo "Backend & Nginx Diagnostic Check"
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

echo ""
echo "1. Checking PM2 Status..."
pm2 list | grep soliflex-backend || print_error "Backend not found in PM2"

echo ""
echo "2. Checking if port 5000 is listening..."
if netstat -tuln 2>/dev/null | grep -q ":5000 " || ss -tuln 2>/dev/null | grep -q ":5000 "; then
    print_ok "Port 5000 is listening"
    netstat -tuln 2>/dev/null | grep ":5000 " || ss -tuln 2>/dev/null | grep ":5000 "
else
    print_error "Port 5000 is NOT listening - backend is not running!"
fi

echo ""
echo "3. Testing backend directly (localhost:5000)..."
HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health 2>/dev/null || echo "000")
if [ "$HEALTH_RESPONSE" = "200" ]; then
    print_ok "Backend health check passed (HTTP $HEALTH_RESPONSE)"
    curl -s http://localhost:5000/health | head -c 100
    echo ""
else
    print_error "Backend health check failed (HTTP $HEALTH_RESPONSE)"
    print_warning "Backend is not responding on localhost:5000"
fi

echo ""
echo "4. Testing departments endpoint directly..."
DEPT_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/departments 2>/dev/null || echo "000")
if [ "$DEPT_RESPONSE" = "200" ]; then
    print_ok "Departments endpoint works (HTTP $DEPT_RESPONSE)"
    curl -s http://localhost:5000/api/departments | head -c 150
    echo ""
else
    print_error "Departments endpoint failed (HTTP $DEPT_RESPONSE)"
fi

echo ""
echo "5. Checking Nginx status..."
if systemctl is-active --quiet nginx; then
    print_ok "Nginx is running"
else
    print_error "Nginx is NOT running"
    echo "  Start with: sudo systemctl start nginx"
fi

echo ""
echo "6. Testing through Nginx (if domain is configured)..."
# Test if we can reach through the domain
if curl -s -o /dev/null -w "%{http_code}" https://transport.soliflexpackaging.com/api/departments 2>/dev/null | grep -q "200\|502"; then
    NGINX_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://transport.soliflexpackaging.com/api/departments 2>/dev/null)
    if [ "$NGINX_CODE" = "200" ]; then
        print_ok "Nginx proxy is working (HTTP 200)"
    elif [ "$NGINX_CODE" = "502" ]; then
        print_error "Nginx returns 502 Bad Gateway"
        print_warning "Nginx cannot reach backend on localhost:5000"
        echo "  Check nginx config: sudo nginx -t"
        echo "  Check nginx error log: sudo tail -f /var/log/nginx/error.log"
    else
        print_warning "Nginx returned HTTP $NGINX_CODE"
    fi
else
    print_warning "Cannot test through domain (may not be accessible from this machine)"
fi

echo ""
echo "7. Checking backend logs..."
echo "Recent backend logs:"
pm2 logs soliflex-backend --lines 10 --nostream 2>/dev/null || print_warning "Could not get PM2 logs"

echo ""
echo "8. Checking Nginx error logs (last 5 lines)..."
sudo tail -5 /var/log/nginx/error.log 2>/dev/null || print_warning "Could not read nginx error log"

echo ""
echo "=========================================="
echo "Summary:"
echo "=========================================="

if [ "$HEALTH_RESPONSE" = "200" ] && [ "$DEPT_RESPONSE" = "200" ]; then
    print_ok "Backend is working correctly on localhost:5000"
    if [ "$NGINX_CODE" = "502" ]; then
        print_error "BUT: Nginx cannot reach backend (502 error)"
        echo ""
        echo "Fix: Check nginx configuration:"
        echo "  1. sudo nano /etc/nginx/sites-available/default"
        echo "  2. Verify 'proxy_pass http://localhost:5000;' in /api/ location"
        echo "  3. sudo nginx -t"
        echo "  4. sudo systemctl reload nginx"
    fi
else
    print_error "Backend is NOT working"
    echo ""
    echo "Fix:"
    echo "  1. Check PM2: pm2 list"
    echo "  2. Check logs: pm2 logs soliflex-backend --lines 50"
    echo "  3. Restart: pm2 restart soliflex-backend"
    echo "  4. Verify: curl http://localhost:5000/health"
fi

echo ""

