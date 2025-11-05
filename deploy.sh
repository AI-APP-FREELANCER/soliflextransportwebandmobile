#!/bin/bash

# Soliflex Packaging Transporter - Deployment Script
# Run this script on your Ubuntu VM after cloning the repository

set -e  # Exit on error

echo "=========================================="
echo "Soliflex Deployment Script"
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

# Step 1: Check if PM2 is installed
print_status "Checking PM2 installation..."
if ! command -v pm2 &> /dev/null; then
    print_error "PM2 is not installed. Installing..."
    sudo npm install -g pm2
else
    print_status "PM2 is installed: $(pm2 --version)"
fi

# Step 2: Stop existing applications
print_status "Stopping existing applications..."
pm2 stop soliflex-backend 2>/dev/null || print_warning "Backend not running"
pm2 stop soliflex-frontend 2>/dev/null || print_warning "Frontend not running"
pm2 delete soliflex-backend 2>/dev/null || print_warning "Backend not found"
pm2 delete soliflex-frontend 2>/dev/null || print_warning "Frontend not found"

# Step 3: Install backend dependencies
print_status "Installing backend dependencies..."
cd "$BACKEND_DIR"
npm install --production

# Step 4: Build Flutter web frontend
print_status "Building Flutter web frontend..."
cd "$PROJECT_DIR"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Get Flutter dependencies
print_status "Getting Flutter dependencies..."
flutter pub get

# Build web release
print_status "Building Flutter web (release mode)..."
flutter build web --release

# Verify build output
if [ ! -d "build/web" ]; then
    print_error "Flutter build failed! build/web directory not found."
    exit 1
fi

print_status "Flutter build completed successfully."

# Step 5: Create logs directory
print_status "Creating logs directory..."
cd "$PROJECT_DIR"
mkdir -p logs

# Step 6: Install http-server if not installed
print_status "Checking http-server installation..."
if ! command -v http-server &> /dev/null; then
    print_status "Installing http-server..."
    sudo npm install -g http-server
else
    print_status "http-server is already installed"
fi

# Step 7: Start applications with PM2
print_status "Starting applications with PM2..."
cd "$PROJECT_DIR"

# Check if ecosystem.config.js exists
if [ ! -f "ecosystem.config.js" ]; then
    print_error "ecosystem.config.js not found!"
    exit 1
fi

# Start PM2 processes
pm2 start ecosystem.config.js

# Step 8: Save PM2 configuration
print_status "Saving PM2 configuration..."
pm2 save

# Step 9: Display status
print_status "PM2 Process Status:"
pm2 list

echo ""
echo "=========================================="
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Backend: http://localhost:3000"
echo "Frontend: http://localhost:4000"
echo ""
echo "Useful commands:"
echo "  pm2 list              - View all processes"
echo "  pm2 logs               - View logs"
echo "  pm2 restart all        - Restart all apps"
echo "  pm2 stop all           - Stop all apps"
echo "  pm2 monit              - Monitor resources"
echo ""
echo "To view logs:"
echo "  pm2 logs soliflex-backend"
echo "  pm2 logs soliflex-frontend"
echo ""

