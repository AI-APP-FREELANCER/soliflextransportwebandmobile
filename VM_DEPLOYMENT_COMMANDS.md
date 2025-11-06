# Ubuntu VM Deployment Commands - Step by Step

Run these commands **on your Ubuntu VM** (via SSH) to host your application.

---

## Prerequisites Check

First, verify you're connected to your VM and check what's already installed:

```bash
# Check if you're on the VM
hostname

# Check Node.js version
node --version

# Check npm version
npm --version

# Check if PM2 is installed
pm2 --version

# Check if Flutter is installed
flutter --version

# Check if http-server is installed
which http-server
```

---

## Step 1: Install Required Dependencies (If Not Already Installed)

Run these commands one by one:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Node.js (v20 LTS) if not installed
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node --version
npm --version

# Install PM2 globally
sudo npm install -g pm2

# Install Flutter (using snap - recommended)
sudo snap install flutter --classic

# OR if snap doesn't work, install manually:
# cd ~
# wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz
# tar xf flutter_linux_3.24.0-stable.tar.xz
# export PATH="$PATH:`pwd`/flutter/bin"
# echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
# source ~/.bashrc

# Verify Flutter installation
flutter --version
flutter doctor

# Install Chrome dependencies (for Flutter web builds)
sudo apt install -y chromium-browser libgtk-3-0 libgbm1

# Install Git (if not already installed)
sudo apt install -y git

# Install http-server globally
sudo npm install -g http-server
```

---

## Step 2: Configure Firewall (UFW) on VM

Even though you've configured Azure NSG, you should also configure the VM's firewall:

```bash
# Allow ports 3000 (backend) and 4000 (frontend)
sudo ufw allow 3000/tcp
sudo ufw allow 4000/tcp
sudo ufw allow 22/tcp  # SSH (important!)

# Enable firewall
sudo ufw enable

# Check firewall status
sudo ufw status
```

---

## Step 3: Clone Repository (If Not Already Cloned)

```bash
# Navigate to home directory
cd ~

# Create apps directory (optional, for organization)
mkdir -p apps
cd apps

# Clone your repository
git clone https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git soliflexweb

# Navigate to project directory
cd soliflexweb
```

**OR if you already have the repository cloned:**

```bash
# Navigate to your project directory
cd ~/apps/soliflexweb
# OR wherever you cloned it
# cd ~/transport/transportwebandmobile/soliflexweb

# Pull latest changes
git pull origin main
```

---

## Step 4: Install Backend Dependencies

```bash
# Make sure you're in the project root
cd ~/apps/soliflexweb
# OR your actual project path

# Navigate to backend directory
cd backend

# Install Node.js dependencies
npm install --production

# Go back to project root
cd ..
```

---

## Step 5: Build Flutter Web Frontend

```bash
# Make sure you're in project root
cd ~/apps/soliflexweb
# OR your actual project path

# Get Flutter dependencies
flutter pub get

# Build Flutter web app (release mode)
flutter build web --release

# Verify build output exists
ls -la build/web/

# You should see index.html and other files
```

---

## Step 6: Stop Previous Apps (If Running)

```bash
# List all PM2 processes
pm2 list

# Stop previous apps (if running)
pm2 stop soliflex-backend 2>/dev/null || echo "Backend not running"
pm2 stop soliflex-frontend 2>/dev/null || echo "Frontend not running"

# Delete previous apps (if exists)
pm2 delete soliflex-backend 2>/dev/null || echo "Backend not found"
pm2 delete soliflex-frontend 2>/dev/null || echo "Frontend not found"

# OR stop all PM2 processes
# pm2 stop all
# pm2 delete all
```

---

## Step 7: Create Logs Directory

```bash
# Make sure you're in project root
cd ~/apps/soliflexweb

# Create logs directory for PM2
mkdir -p logs
```

---

## Step 8: Start Applications with PM2

```bash
# Make sure you're in project root
cd ~/apps/soliflexweb

# Verify ecosystem.config.js exists
ls -la ecosystem.config.js

# Start both apps using PM2 ecosystem file
pm2 start ecosystem.config.js

# Save PM2 configuration (so it persists after reboot)
pm2 save

# Setup PM2 to start on system boot
pm2 startup
# This will output a command - COPY and RUN it with sudo
# Example output: sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u username --hp /home/username
# Replace username with your actual username
```

**After running `pm2 startup`, you'll see a command like this:**
```bash
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u your-username --hp /home/your-username
```
**Copy and run that exact command with sudo.**

---

## Step 9: Verify Deployment

```bash
# Check PM2 status
pm2 list

# You should see:
# - soliflex-backend (status: online)
# - soliflex-frontend (status: online)

# View logs
pm2 logs

# View specific app logs
pm2 logs soliflex-backend
pm2 logs soliflex-frontend

# Check if ports are listening
sudo netstat -tulpn | grep 3000
sudo netstat -tulpn | grep 4000

# Test backend health endpoint
curl http://localhost:3000/health

# Should return: {"status":"ok","message":"Soliflex Backend API is running"}
```

---

## Step 10: Test from External Machine

From your local machine (Windows), test the deployment:

```bash
# Replace YOUR_VM_IP with your Azure VM's public IP address
# Test backend
curl http://YOUR_VM_IP:3000/health

# Should return: {"status":"ok","message":"Soliflex Backend API is running"}
```

**Or open in browser:**
- Backend: `http://YOUR_VM_IP:3000/health`
- Frontend: `http://YOUR_VM_IP:4000`

---

## Quick Deployment Script (Alternative)

If you prefer to use the deployment script:

```bash
# Navigate to project directory
cd ~/apps/soliflexweb

# Make deploy script executable
chmod +x deploy.sh

# Run deployment script
./deploy.sh
```

This script will:
- Check and install dependencies
- Stop existing apps
- Install backend dependencies
- Build Flutter web
- Start apps with PM2
- Save PM2 configuration

**After the script runs, you still need to:**
```bash
# Setup PM2 to start on boot
pm2 startup
# Copy and run the generated command with sudo
```

---

## Useful PM2 Commands

```bash
# View all processes
pm2 list

# View logs (all apps)
pm2 logs

# View logs for specific app
pm2 logs soliflex-backend
pm2 logs soliflex-frontend

# View last 50 lines of logs
pm2 logs --lines 50

# Restart app
pm2 restart soliflex-backend
pm2 restart soliflex-frontend
pm2 restart all

# Stop app
pm2 stop soliflex-backend
pm2 stop all

# Delete app
pm2 delete soliflex-backend
pm2 delete all

# Monitor resources (CPU, memory)
pm2 monit

# View app information
pm2 info soliflex-backend
pm2 info soliflex-frontend

# Reload app (zero-downtime)
pm2 reload soliflex-backend

# Save current PM2 configuration
pm2 save
```

---

## Troubleshooting

### Backend not starting:

```bash
# Check logs
pm2 logs soliflex-backend --lines 50

# Check if port 3000 is in use
sudo lsof -i :3000
sudo netstat -tulpn | grep 3000

# Check Node.js version
node --version

# Check if server.js exists
ls -la backend/server.js

# Test backend manually
cd ~/apps/soliflexweb/backend
node server.js
# Press Ctrl+C to stop
```

### Frontend not serving:

```bash
# Check logs
pm2 logs soliflex-frontend --lines 50

# Check if port 4000 is in use
sudo lsof -i :4000
sudo netstat -tulpn | grep 4000

# Verify build directory exists
ls -la ~/apps/soliflexweb/build/web/

# Check if http-server is installed
which http-server

# Test frontend manually
cd ~/apps/soliflexweb
http-server build/web -p 4000
# Press Ctrl+C to stop
```

### PM2 not starting on boot:

```bash
# Run startup command again
pm2 startup

# Copy and run the generated command with sudo
# Example: sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u username --hp /home/username

# Save PM2 configuration
pm2 save

# Test by rebooting
sudo reboot
# After reboot, SSH back in and check if PM2 apps are running
pm2 list
```

### Flutter build fails:

```bash
# Check Flutter installation
flutter doctor

# Clean Flutter build
flutter clean

# Get dependencies again
flutter pub get

# Try building again
flutter build web --release

# Check for specific errors
flutter build web --release --verbose
```

### Port already in use:

```bash
# Find process using port 3000
sudo lsof -i :3000
# Kill the process (replace PID with actual process ID)
sudo kill -9 PID

# Find process using port 4000
sudo lsof -i :4000
# Kill the process
sudo kill -9 PID
```

---

## Complete One-Liner (After Initial Setup)

Once everything is set up, you can use this one-liner to update and redeploy:

```bash
cd ~/apps/soliflexweb && \
git pull origin main && \
cd backend && npm install --production && cd .. && \
flutter pub get && \
flutter build web --release && \
pm2 restart all && \
pm2 logs --lines 20
```

---

## Summary

✅ **Backend**: Running on port 3000 via PM2  
✅ **Frontend**: Running on port 4000 via PM2  
✅ **PM2**: Auto-restart and startup on boot  
✅ **Firewall**: Ports 3000 and 4000 open (UFW)  
✅ **Azure NSG**: Ports 3000 and 4000 open (already configured)

**Access URLs:**
- Backend API: `http://YOUR_VM_IP:3000`
- Frontend: `http://YOUR_VM_IP:4000`
- Health Check: `http://YOUR_VM_IP:3000/health`

Replace `YOUR_VM_IP` with your Azure VM's public IP address.

