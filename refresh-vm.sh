#!/bin/bash

# Soliflex Packaging Transporter - Complete Refresh Script
# This script pulls latest code and fully refreshes the application on VM

set -e  # Exit on error

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

# Step 1: Pull latest code from git
print_status "Pulling latest code from git..."
git fetch origin
git pull origin main
print_status "Code updated from git"

# Step 2: Verify key files are updated
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

# Step 3: Stop and delete all PM2 processes
print_status "Stopping and deleting all PM2 processes..."
pm2 stop all 2>/dev/null || print_warning "No processes to stop"
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
npm install --production
cd "$PROJECT_DIR"
print_status "Backend dependencies updated"

# Step 7: Get Flutter dependencies (clean state)
print_status "Getting Flutter dependencies (clean state)..."
flutter clean
flutter pub get
print_status "Flutter dependencies updated"

# Step 8: Build Flutter web frontend (fresh build)
print_status "Building Flutter web frontend (release mode)..."
flutter build web --release --no-tree-shake-icons

# Verify build output
if [ ! -d "build/web" ]; then
    print_error "Flutter build failed! build/web directory not found."
    exit 1
fi

print_status "Flutter build completed successfully."

# Step 9: Create logs directory
print_status "Creating logs directory..."
mkdir -p logs

# Step 10: Start applications with PM2 (fresh start)
print_status "Starting applications with PM2..."
cd "$PROJECT_DIR"

# Check if ecosystem.config.js exists
if [ ! -f "ecosystem.config.js" ]; then
    print_error "ecosystem.config.js not found!"
    exit 1
fi

# Start PM2 processes
pm2 start ecosystem.config.js

# Step 11: Save PM2 configuration
print_status "Saving PM2 configuration..."
pm2 save

# Step 12: Wait a moment for services to start
print_status "Waiting for services to start..."
sleep 5

# Step 13: Display status and verify
print_status "PM2 Process Status:"
pm2 list

echo ""
print_status "Checking backend health (port 5000)..."
sleep 2
if curl -f http://localhost:5000/health > /dev/null 2>&1; then
    print_status "✓ Backend is running and healthy on port 5000"
else
    print_warning "Backend health check failed - check logs with: pm2 logs soliflex-backend"
    print_warning "Backend may still be starting, wait a few seconds and check again"
fi

echo ""
print_status "Checking frontend (port 8081)..."
sleep 2
if curl -f http://localhost:8081 > /dev/null 2>&1; then
    print_status "✓ Frontend is running on port 8081"
else
    print_warning "Frontend check failed - check logs with: pm2 logs soliflex-frontend"
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
echo "To verify new features:"
echo "  1. Check backend logs for rate limit fixes: pm2 logs soliflex-backend | grep 'rate'"
echo "  2. Test backend: curl http://localhost:5000/health"
echo "  3. Check for JSON parsing fixes in api_service.dart"
echo ""
echo "Cache clearing summary:"
echo "  ✓ Flutter build cache cleared"
echo "  ✓ .dart_tool directory cleared"
echo "  ✓ PM2 logs flushed"
echo "  ✓ Fresh build completed"
echo ""


