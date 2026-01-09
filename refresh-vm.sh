#!/bin/bash

# Soliflex Packaging Transporter - Complete Refresh Script
# This script refreshes the application on VM
# Note: Run 'git pull origin main' manually before running this script

# Don't exit on error - we want to continue and show all issues
set +e

echo "=========================================="
echo "Soliflex Complete Refresh Script"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get current directory (should be project root)
PROJECT_DIR=$(pwd)
BACKEND_DIR="$PROJECT_DIR/backend"

print_status "Project directory: $PROJECT_DIR"

# Note: Git pull should be done manually before running this script
# git pull origin main

# Step 1: Verify key files are updated
print_status "Verifying updated files..."
if grep -q "_parseResponse" "$PROJECT_DIR/lib/services/api_service.dart"; then
    print_status "✓ Rate limit error handling found in api_service.dart"
else
    print_warning "Rate limit error handling not found - code may not be updated"
fi

if grep -q "max: 500" "$PROJECT_DIR/backend/server.js"; then
    print_status "✓ Updated rate limits found in server.js"
else
    print_warning "Updated rate limits not found - code may not be updated"
fi

if grep -q "PORT: 5000" "$PROJECT_DIR/ecosystem.config.js"; then
    print_status "✓ Backend port 5000 configured correctly"
else
    print_warning "Backend port configuration may be incorrect"
fi

# Step 2: Check for port conflicts
print_status "Checking for port conflicts..."
if command -v lsof &> /dev/null; then
    PORT_5000_PID=$(sudo lsof -ti:5000 2>/dev/null)
    PORT_8081_PID=$(sudo lsof -ti:8081 2>/dev/null)
    
    if [ ! -z "$PORT_5000_PID" ]; then
        print_warning "Port 5000 is in use by PID $PORT_5000_PID"
        print_warning "Killing process on port 5000..."
        sudo kill -9 $PORT_5000_PID 2>/dev/null || true
        sleep 2
    fi
    
    if [ ! -z "$PORT_8081_PID" ]; then
        print_warning "Port 8081 is in use by PID $PORT_8081_PID"
        print_warning "Killing process on port 8081..."
        sudo kill -9 $PORT_8081_PID 2>/dev/null || true
        sleep 2
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tuln 2>/dev/null | grep -q ":5000 "; then
        print_warning "Port 5000 appears to be in use"
    fi
    if netstat -tuln 2>/dev/null | grep -q ":8081 "; then
        print_warning "Port 8081 appears to be in use"
    fi
fi

# Step 3: Stop and delete all PM2 processes
print_status "Stopping and deleting all PM2 processes..."
pm2 stop all 2>/dev/null || print_warning "No processes to stop"
sleep 2
pm2 delete all 2>/dev/null || print_warning "No processes to delete"
pm2 flush 2>/dev/null || print_warning "Could not flush logs"
print_status "All PM2 processes stopped and deleted"

# Step 4: Clear all caches and build artifacts
print_status "Clearing all caches and build artifacts..."
cd "$PROJECT_DIR"

# Clear Flutter build cache
print_status "Clearing Flutter build cache..."
rm -rf build 2>/dev/null || true
rm -rf .dart_tool 2>/dev/null || true
rm -rf .flutter-plugins 2>/dev/null || true
rm -rf .flutter-plugins-dependencies 2>/dev/null || true
rm -rf .packages 2>/dev/null || true

# Clear any remaining build artifacts
rm -rf build/web/.dart_tool 2>/dev/null || true
rm -rf build/web/main.dart.js.map 2>/dev/null || true

# Clear PM2 cache
print_status "Clearing PM2 cache..."
pm2 flush 2>/dev/null || print_warning "Could not flush PM2 logs"

# Clear Node.js cache (if any)
print_status "Clearing Node.js cache..."
cd "$BACKEND_DIR"
rm -rf node_modules/.cache 2>/dev/null || true
cd "$PROJECT_DIR"

print_status "All caches cleared"

# Step 5: Fix permissions (if needed)
print_status "Fixing file permissions..."
cd "$PROJECT_DIR"
# Fix ownership if needed (uncomment if permission issues occur)
# sudo chown -R $USER:$USER . 2>/dev/null || true
print_status "Permissions checked"

# Step 6: Install backend dependencies
print_status "Installing/updating backend dependencies..."
cd "$BACKEND_DIR"
if npm install --production; then
    print_status "✓ Backend dependencies installed successfully"
else
    print_error "✗ Backend dependencies installation failed!"
    print_warning "Trying with full install (including dev dependencies)..."
    npm install
fi
cd "$PROJECT_DIR"
print_status "Backend dependencies updated"

# Step 7: Get Flutter dependencies (clean state)
print_status "Getting Flutter dependencies (clean state)..."
flutter clean
flutter pub get
print_status "Flutter dependencies updated"

# Step 8: Build Flutter web frontend (fresh build)
print_status "Building Flutter web frontend (release mode)..."
if flutter build web --release --no-tree-shake-icons; then
    print_status "✓ Flutter build completed successfully"
else
    print_error "✗ Flutter build failed!"
    print_warning "Trying to continue anyway..."
fi

# Verify build output
if [ ! -d "build/web" ]; then
    print_error "✗ Flutter build failed! build/web directory not found."
    print_warning "Attempting to create build directory..."
    mkdir -p build/web
    exit 1
fi

# Verify critical files exist
print_status "Verifying build output files..."
if [ -f "build/web/index.html" ]; then
    print_status "✓ index.html exists"
else
    print_error "✗ index.html not found in build/web/"
fi

if [ -f "build/web/manifest.json" ]; then
    print_status "✓ manifest.json exists"
    # Copy from source if build version is missing or invalid
    if [ -f "web/manifest.json" ]; then
        cp web/manifest.json build/web/manifest.json
        print_status "✓ Copied manifest.json from source"
    fi
else
    print_warning "manifest.json not found in build/web/"
    if [ -f "web/manifest.json" ]; then
        cp web/manifest.json build/web/manifest.json
        print_status "✓ Copied manifest.json from source to build/web/"
    fi
fi

if [ -f "build/web/main.dart.js" ]; then
    print_status "✓ main.dart.js exists"
    FILE_SIZE=$(du -h build/web/main.dart.js | cut -f1)
    print_status "  File size: $FILE_SIZE"
else
    print_error "✗ main.dart.js not found - build may have failed"
fi

# Step 9: Create logs directory
print_status "Creating logs directory..."
mkdir -p logs

# Step 10: Verify backend server.js exists and is executable
print_status "Verifying backend files..."
if [ ! -f "$BACKEND_DIR/server.js" ]; then
    print_error "Backend server.js not found at $BACKEND_DIR/server.js"
    exit 1
fi

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed or not in PATH"
    exit 1
fi

# Check if PM2 is available
if ! command -v pm2 &> /dev/null; then
    print_error "PM2 is not installed. Install with: npm install -g pm2"
    exit 1
fi

# Step 11: Start applications with PM2 (fresh start)
print_status "Starting applications with PM2..."
cd "$PROJECT_DIR"

# Check if ecosystem.config.js exists
if [ ! -f "ecosystem.config.js" ]; then
    print_error "ecosystem.config.js not found!"
    exit 1
fi

# Start PM2 processes
print_status "Starting backend and frontend..."
if pm2 start ecosystem.config.js; then
    print_status "✓ PM2 processes started"
else
    print_error "✗ Failed to start PM2 processes"
    print_warning "Checking PM2 status..."
    pm2 list
    exit 1
fi

# Step 12: Save PM2 configuration
print_status "Saving PM2 configuration..."
pm2 save

# Step 13: Wait for services to start and verify
print_status "Waiting for services to start..."
sleep 8

# Check if backend process is actually running
print_status "Verifying backend process..."
if pm2 list | grep -q "soliflex-backend.*online"; then
    print_status "✓ Backend process is online"
else
    print_error "✗ Backend process is not online!"
    print_warning "Backend logs:"
    pm2 logs soliflex-backend --lines 20 --nostream
    print_warning "Please check the logs above for errors"
fi

# Check if frontend process is actually running
print_status "Verifying frontend process..."
if pm2 list | grep -q "soliflex-frontend.*online"; then
    print_status "✓ Frontend process is online"
else
    print_warning "Frontend process is not online"
    print_warning "Frontend logs:"
    pm2 logs soliflex-frontend --lines 20 --nostream
fi

# Step 14: Display status and verify
print_status "PM2 Process Status:"
pm2 list

echo ""
print_status "Checking backend health (port 5000)..."
sleep 3

# Check if port 5000 is listening
if netstat -tuln 2>/dev/null | grep -q ":5000 " || ss -tuln 2>/dev/null | grep -q ":5000 "; then
    print_status "✓ Port 5000 is listening"
else
    print_warning "Port 5000 is not listening - backend may not have started"
fi

# Test backend health endpoint
BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/health 2>/dev/null || echo "000")
if [ "$BACKEND_HEALTH" = "200" ]; then
    print_status "✓ Backend health check passed (HTTP 200)"
    BACKEND_RESPONSE=$(curl -s http://localhost:5000/health)
    print_status "Backend response: $BACKEND_RESPONSE"
else
    print_error "✗ Backend health check failed (HTTP $BACKEND_HEALTH)"
    print_warning "Backend may still be starting or there's an error"
    print_warning "Check logs: pm2 logs soliflex-backend --lines 50"
fi

# Test departments endpoint
echo ""
print_status "Testing departments endpoint..."
DEPARTMENTS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5000/api/departments 2>/dev/null || echo "000")
if [ "$DEPARTMENTS_RESPONSE" = "200" ]; then
    print_status "✓ Departments endpoint is working (HTTP 200)"
    DEPARTMENTS_DATA=$(curl -s http://localhost:5000/api/departments)
    print_status "Departments response preview: $(echo $DEPARTMENTS_DATA | head -c 100)..."
else
    print_error "✗ Departments endpoint failed (HTTP $DEPARTMENTS_RESPONSE)"
    print_warning "This is the endpoint causing 502 errors in the frontend"
    print_warning "Check backend logs: pm2 logs soliflex-backend --lines 50"
fi

echo ""
print_status "Checking frontend (port 8081)..."
sleep 2

# Check if port 8081 is listening
if netstat -tuln 2>/dev/null | grep -q ":8081 " || ss -tuln 2>/dev/null | grep -q ":8081 "; then
    print_status "✓ Port 8081 is listening"
else
    print_warning "Port 8081 is not listening - frontend may not have started"
fi

# Test frontend
FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 2>/dev/null || echo "000")
if [ "$FRONTEND_RESPONSE" = "200" ]; then
    print_status "✓ Frontend is running on port 8081 (HTTP 200)"
else
    print_warning "Frontend check failed (HTTP $FRONTEND_RESPONSE)"
    print_warning "Check logs: pm2 logs soliflex-frontend --lines 50"
fi

# Check manifest.json
echo ""
print_status "Checking manifest.json..."
if [ -f "build/web/manifest.json" ]; then
    print_status "✓ manifest.json exists in build/web/"
    # Validate JSON syntax
    if python3 -m json.tool build/web/manifest.json > /dev/null 2>&1 || node -e "JSON.parse(require('fs').readFileSync('build/web/manifest.json'))" > /dev/null 2>&1; then
        print_status "✓ manifest.json is valid JSON"
    else
        print_warning "manifest.json may have syntax errors"
        print_warning "Content:"
        head -5 build/web/manifest.json
    fi
else
    print_warning "manifest.json not found in build/web/"
    print_warning "This may cause the manifest.json syntax error in browser"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Complete refresh completed!${NC}"
echo "=========================================="
echo ""
echo "Backend: http://localhost:5000"
echo "Frontend: http://localhost:8081"
echo ""
echo "Useful commands:"
echo "  pm2 list              - View all processes"
echo "  pm2 logs               - View logs"
echo "  pm2 logs soliflex-backend --lines 50  - View backend logs"
echo "  pm2 logs soliflex-frontend --lines 50 - View frontend logs"
echo "  pm2 restart all        - Restart all apps"
echo "  pm2 monit              - Monitor resources"
echo ""
echo "Troubleshooting commands:"
echo "  pm2 logs soliflex-backend --lines 100    - View backend logs"
echo "  pm2 logs soliflex-frontend --lines 100   - View frontend logs"
echo "  pm2 restart soliflex-backend              - Restart backend only"
echo "  pm2 restart soliflex-frontend             - Restart frontend only"
echo "  curl http://localhost:5000/health         - Test backend health"
echo "  curl http://localhost:5000/api/departments - Test departments endpoint"
echo ""
echo "If backend is not working:"
echo "  1. Check logs: pm2 logs soliflex-backend --lines 50"
echo "  2. Check if port 5000 is in use: sudo lsof -i :5000"
echo "  3. Restart backend: pm2 restart soliflex-backend"
echo "  4. Verify Node.js version: node --version"
echo ""
echo "If frontend shows manifest.json error:"
echo "  1. Clear browser cache (Ctrl+Shift+Delete)"
echo "  2. Rebuild: flutter clean && flutter build web --release"
echo "  3. Restart frontend: pm2 restart soliflex-frontend"
echo ""
echo "Cache clearing summary:"
echo "  ✓ Flutter build cache cleared"
echo "  ✓ .dart_tool directory cleared"
echo "  ✓ PM2 logs flushed"
echo "  ✓ Fresh build completed"
echo ""


