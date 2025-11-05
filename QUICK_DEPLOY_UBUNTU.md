# Quick Deployment Commands - Ubuntu VM

## Repository URL
**https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git**

---

## Complete Deployment Commands (Copy & Paste)

Copy and paste these commands one by one on your Ubuntu VM:

### 1. Install Dependencies

```bash
sudo apt update && sudo apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g pm2
sudo snap install flutter --classic
sudo apt install -y git chromium-browser libgtk-3-0 libgbm1
sudo npm install -g http-server
```

### 2. Configure Firewall

```bash
sudo ufw allow 3000/tcp
sudo ufw allow 4000/tcp
sudo ufw allow 22/tcp
sudo ufw enable
sudo ufw status
```

### 3. Clone Repository

```bash
cd ~
mkdir -p apps
cd apps
git clone https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git soliflexweb
cd soliflexweb
```

### 4. Setup Backend

```bash
cd backend
npm install --production
cd ..
```

### 5. Build Flutter Web

```bash
flutter pub get
flutter build web --release
```

### 6. Stop Previous Apps (if running)

```bash
pm2 stop all
pm2 delete all
```

### 7. Start with PM2

```bash
pm2 start ecosystem.config.js
pm2 save
pm2 startup
# Copy and run the command that PM2 outputs (with sudo)
```

### 8. Verify Deployment

```bash
pm2 list
pm2 logs
curl http://localhost:3000/health
```

---

## Quick Update Commands (When Code Changes)

```bash
cd ~/apps/soliflexweb
git pull origin main
flutter pub get
flutter build web --release
cd backend && npm install --production && cd ..
pm2 restart all
pm2 logs
```

---

## Access URLs

- **Backend**: `http://YOUR_VM_IP:3000`
- **Frontend**: `http://YOUR_VM_IP:4000`
- **Health Check**: `http://YOUR_VM_IP:3000/health`

Replace `YOUR_VM_IP` with your Azure VM's public IP address.

---

## Useful PM2 Commands

```bash
# View all processes
pm2 list

# View logs
pm2 logs

# Restart all
pm2 restart all

# Stop all
pm2 stop all

# Monitor resources
pm2 monit
```

