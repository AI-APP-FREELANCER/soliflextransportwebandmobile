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
if grep -q "assign-vehicle-to-order" "$PROJECT_DIR/backend/routes/orderRoutes.js"; then
    print_status "✓ New vehicle assignment endpoint found"
else
    print_warning "Vehicle assignment endpoint not found - code may not be updated"
fi

if grep -q "isOrderCompleted" "$PROJECT_DIR/lib/screens/orders_dashboard_screen.dart"; then
    print_status "✓ Updated filtering logic found"
else
    print_warning "Updated filtering logic not found - code may not be updated"
fi

# Step 3: Stop and delete all PM2 processes
print_status "Stopping and deleting all PM2 processes..."
pm2 stop all 2>/dev/null || print_warning "No processes to stop"
pm2 delete all 2>/dev/null || print_warning "No processes to delete"
pm2 flush 2>/dev/null || print_warning "Could not flush logs"
print_status "All PM2 processes stopped and deleted"

# Step 4: Clear any cached builds
print_status "Clearing old build artifacts..."
cd "$PROJECT_DIR"
rm -rf build/web/.dart_tool 2>/dev/null || true
rm -rf build/web/main.dart.js.map 2>/dev/null || true
print_status "Build cache cleared"

# Step 5: Install backend dependencies
print_status "Installing/updating backend dependencies..."
cd "$BACKEND_DIR"
npm install
cd "$PROJECT_DIR"
print_status "Backend dependencies updated"

# Step 6: Get Flutter dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Step 7: Build Flutter web frontend (fresh build)
print_status "Building Flutter web frontend (release mode)..."
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

# Verify build output
if [ ! -d "build/web" ]; then
    print_error "Flutter build failed! build/web directory not found."
    exit 1
fi

print_status "Flutter build completed successfully."

# Step 8: Create logs directory
print_status "Creating logs directory..."
mkdir -p logs

# Step 9: Start applications with PM2 (fresh start)
print_status "Starting applications with PM2..."
cd "$PROJECT_DIR"

# Check if ecosystem.config.js exists
if [ ! -f "ecosystem.config.js" ]; then
    print_error "ecosystem.config.js not found!"
    exit 1
fi

# Start PM2 processes
pm2 start ecosystem.config.js

# Step 10: Save PM2 configuration
print_status "Saving PM2 configuration..."
pm2 save

# Step 11: Wait a moment for services to start
sleep 3

# Step 12: Display status and verify
print_status "PM2 Process Status:"
pm2 list

echo ""
print_status "Checking backend health..."
sleep 2
if curl -f http://localhost:3000/health > /dev/null 2>&1; then
    print_status "✓ Backend is running and healthy"
else
    print_warning "Backend health check failed - check logs with: pm2 logs soliflex-backend"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Complete refresh completed!${NC}"
echo "=========================================="
echo ""
echo "Backend: http://localhost:3000"
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
echo "  1. Check backend logs for new endpoints: pm2 logs soliflex-backend | grep 'assign-vehicle'"
echo "  2. Test backend: curl http://localhost:3000/health"
echo ""


