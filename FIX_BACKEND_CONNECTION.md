# Fix Backend Connection Error

## Problem
- `ERR_CONNECTION_REFUSED` when trying to connect to `localhost:3000/api/login`
- Frontend is trying to connect to `localhost:3000` which is your local machine, not the VM

## Solution

I've updated the API service to automatically use the current hostname for web builds. This means:
- If you access the app at `http://YOUR_VM_IP:8081`, it will connect to `http://YOUR_VM_IP:3000/api`
- If you access locally at `http://localhost:8081`, it will connect to `http://localhost:3000/api`

## Steps to Fix

### Step 1: Verify Backend is Running on VM

```bash
# On Ubuntu VM, check if backend is running
pm2 list

# Check backend logs
pm2 logs soliflex-backend --lines 20

# Test backend locally on VM
curl http://localhost:3000/health
```

### Step 2: Rebuild Flutter Web with Updated Code

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Pull latest code (if you pushed the fix)
git pull origin main

# OR manually update the file (if you haven't pushed yet)
# The fix is already in your local codebase

# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none
```

### Step 3: Restart PM2 Apps

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Restart apps
pm2 stop all
pm2 delete all
pm2 start ecosystem.config.js
pm2 save

# Check status
pm2 list
pm2 logs
```

### Step 4: Test Backend Connection

```bash
# On VM, test backend
curl http://localhost:3000/health

# Should return: {"status":"ok","message":"Soliflex Backend API is running"}

# Test from your browser
# Open: http://YOUR_VM_IP:3000/health
```

### Step 5: Test Frontend

1. **Open in browser**: `http://YOUR_VM_IP:8081`
2. **Check browser console** (F12) - should NOT see `ERR_CONNECTION_REFUSED`
3. **Try to login** - should connect to `http://YOUR_VM_IP:3000/api/login`

---

## What Changed

The API service now uses:
- **Web**: Current hostname (automatically detects VM IP or localhost)
- **Mobile**: localhost (as before)

This means when you access the app at `http://20.244.105.1:8081`, it will automatically connect to `http://20.244.105.1:3000/api`.

---

## Troubleshooting

### If backend is not running:

```bash
# On VM, check PM2 status
pm2 list

# If backend is not running, start it
pm2 start ecosystem.config.js

# Check logs for errors
pm2 logs soliflex-backend
```

### If backend is running but not accessible:

```bash
# Check if port 3000 is listening
sudo netstat -tulpn | grep 3000

# Check firewall
sudo ufw status

# Make sure port 3000 is allowed
sudo ufw allow 3000/tcp
```

### If you still see connection errors:

1. **Check Azure NSG rules** - Make sure port 3000 is open
2. **Check backend logs** - `pm2 logs soliflex-backend`
3. **Test backend directly** - `curl http://YOUR_VM_IP:3000/health`

---

## Verify Everything Works

After rebuilding and restarting:

1. **Backend**: `http://YOUR_VM_IP:3000/health` should work
2. **Frontend**: `http://YOUR_VM_IP:8081` should load
3. **Login**: Should connect to backend without errors
4. **Browser Console**: Should NOT show `ERR_CONNECTION_REFUSED`

