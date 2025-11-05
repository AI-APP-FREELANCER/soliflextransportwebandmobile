# Deployment Guide: Soliflex Packaging Transporter
## Azure VM Ubuntu Server Deployment

This guide provides step-by-step commands to deploy your Flutter web frontend and Node.js backend to an Azure Ubuntu VM.

---

## Part 1: Push Code to GitHub (Run on Windows)

### Step 1.1: Initialize Git and Push to GitHub

Open PowerShell or Git Bash on your Windows machine and run:

```powershell
# Navigate to your project directory
cd C:\Users\shyam\Documents\Dev\soliflexweb\new

# Check git status
git status

# If not a git repo, initialize it
git init

# Add all files
git add .

# Commit changes
git commit -m "Deploy: Soliflex Packaging Transporter with enhanced UI and workflow system"

# Add remote (your GitHub repository)
git remote add origin https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git

# Or if you already have a remote, check and update it:
git remote -v
git remote set-url origin https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git

# Push to GitHub
git branch -M main
git push -u origin main
```

---

## Part 2: Azure VM Setup (Run on Ubuntu VM)

### Step 2.1: Connect to Your Azure VM

```bash
# SSH into your Azure VM (replace with your VM details)
ssh username@your-vm-ip-address
```

### Step 2.2: Install Required Dependencies

Copy and paste these commands one by one:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install Node.js (v20 LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify Node.js installation
node --version
npm --version

# Install PM2 globally
sudo npm install -g pm2

# Install Flutter (using snap - recommended)
sudo snap install flutter --classic

# OR install Flutter manually (if snap doesn't work):
# cd ~
# wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.x.x-stable.tar.xz
# tar xf flutter_linux_3.x.x-stable.tar.xz
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

# Install http-server globally (for serving Flutter web)
sudo npm install -g http-server
```

### Step 2.3: Configure Firewall

```bash
# Allow ports 3000 (backend) and 8081 (frontend)
sudo ufw allow 3000/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 22/tcp  # SSH
sudo ufw allow 80/tcp  # HTTP (optional, for Nginx)
sudo ufw allow 443/tcp # HTTPS (optional, for SSL)

# Enable firewall
sudo ufw enable

# Check firewall status
sudo ufw status
```

---

## Part 3: Clone and Setup Project (Run on Ubuntu VM)

### Step 3.1: Clone Repository

```bash
# Navigate to home directory
cd ~

# Create apps directory (optional)
mkdir -p apps
cd apps

# Clone your repository
git clone https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git soliflexweb

# Navigate to project directory
cd soliflexweb
```

### Step 3.2: Setup Backend

```bash
# Navigate to backend directory
cd backend

# Install Node.js dependencies
npm install --production

# Create necessary data directories if they don't exist
mkdir -p data

# Create CSV files with headers if they don't exist
# (You may want to copy your existing data files here)
# For now, the backend will create them automatically when needed
```

### Step 3.3: Build Flutter Web Frontend

```bash
# Navigate back to project root
cd ~/apps/soliflexweb

# Get Flutter dependencies
flutter pub get

# Build Flutter web app (release mode)
flutter build web --release

# Verify build output exists
ls -la build/web/
```

---

## Part 4: Stop Previous App and Start with PM2 (Run on Ubuntu VM)

### Step 4.1: Stop Previous Application

```bash
# Navigate to project directory
cd ~/apps/soliflexweb

# List all PM2 processes
pm2 list

# Stop previous app (if running)
pm2 stop soliflex-backend
pm2 stop soliflex-frontend

# Delete previous app (if exists)
pm2 delete soliflex-backend
pm2 delete soliflex-frontend

# OR stop all PM2 processes
pm2 stop all
pm2 delete all
```

### Step 4.2: Start Applications with PM2

```bash
# Make sure you're in the project root
cd ~/apps/soliflexweb

# Verify ecosystem.config.js exists
ls -la ecosystem.config.js

# Start both apps using PM2 ecosystem file
pm2 start ecosystem.config.js

# Save PM2 configuration (so it persists after reboot)
pm2 save

# Setup PM2 to start on system boot
pm2 startup
# This will output a command - copy and run it with sudo
# Example output: sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u username --hp /home/username
# Replace username with your actual username
```

### Step 4.3: Verify Deployment

```bash
# Check PM2 status
pm2 list

# View logs
pm2 logs

# Check specific app logs
pm2 logs soliflex-backend
pm2 logs soliflex-frontend

# Monitor resources
pm2 monit

# Check if ports are listening
sudo netstat -tulpn | grep 3000
sudo netstat -tulpn | grep 8081

# Test backend (replace YOUR_VM_IP with your actual VM IP)
curl http://localhost:3000/health
```

---

## Part 5: Test Your Deployment

### Step 5.1: Test Backend

From your local machine or VM:

```bash
# Test backend health endpoint
curl http://YOUR_VM_IP:3000/health

# Should return: {"status":"ok","message":"Soliflex Backend API is running"}
```

### Step 5.2: Test Frontend

Open in your browser:
```
http://YOUR_VM_IP:8081
```

---

## Part 6: Useful PM2 Commands (Run on Ubuntu VM)

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

## Part 7: Update Deployment (Run on Ubuntu VM)

When you push new code to GitHub:

```bash
# SSH into VM
ssh username@your-vm-ip

# Navigate to project directory
cd ~/apps/soliflexweb

# Pull latest changes
git pull origin main

# Rebuild Flutter web (if frontend changed)
flutter pub get
flutter build web --release

# Install backend dependencies (if backend changed)
cd backend
npm install --production
cd ..

# Restart PM2 apps
pm2 restart all

# Check logs
pm2 logs
```

---

## Part 8: Quick Deployment Script (Run on Ubuntu VM)

If you want to use the deployment script:

```bash
# Navigate to project directory
cd ~/apps/soliflexweb

# Make deploy script executable
chmod +x deploy.sh

# Run deployment script
./deploy.sh
```

This script will:
- Stop existing apps
- Install dependencies
- Build Flutter web
- Start apps with PM2
- Save PM2 configuration

---

## Part 9: Troubleshooting

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
```

### Frontend not serving:

```bash
# Check logs
pm2 logs soliflex-frontend --lines 50

# Check if port 8081 is in use
sudo lsof -i :8081
sudo netstat -tulpn | grep 8081

# Verify build directory exists
ls -la ~/apps/soliflexweb/build/web/

# Check if http-server is installed
which http-server

# Test frontend manually
cd ~/apps/soliflexweb
http-server build/web -p 8081
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
# After reboot, check if PM2 apps are running
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

---

## Part 10: Nginx Reverse Proxy (Optional)

If you want to use Nginx as a reverse proxy:

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/soliflex
```

Paste this configuration (replace YOUR_VM_IP with your actual IP or domain):

```nginx
server {
    listen 80;
    server_name YOUR_VM_IP;

    # Frontend (Flutter web)
    location / {
        proxy_pass http://localhost:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Then:

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/soliflex /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Enable Nginx on boot
sudo systemctl enable nginx
```

Now you can access:
- Frontend: `http://YOUR_VM_IP`
- Backend: `http://YOUR_VM_IP/api`

---

## Summary

✅ **Backend**: Running on port 3000 via PM2  
✅ **Frontend**: Running on port 8081 via PM2  
✅ **PM2**: Auto-restart and startup on boot  
✅ **Firewall**: Ports 3000 and 8081 open  

**Access URLs:**
- Backend API: `http://YOUR_VM_IP:3000`
- Frontend: `http://YOUR_VM_IP:8081`
- With Nginx: `http://YOUR_VM_IP` (frontend) and `http://YOUR_VM_IP/api` (backend)

**Quick Reference:**

```bash
# Start apps
pm2 start ecosystem.config.js

# Stop apps
pm2 stop all

# Restart apps
pm2 restart all

# View logs
pm2 logs

# Update and redeploy
cd ~/apps/soliflexweb && git pull && flutter build web --release && pm2 restart all
```

