# Fix for 500 Error on VM

## Problem
The backend is blocking requests due to CORS configuration. The domain `https://transport.soliflexpackaging.com` is not in the allowed origins list.

## Solution

### Step 1: Push the updated code
The `backend/server.js` file has been updated with the correct CORS domain. Push this to your repository:

```bash
git add backend/server.js
git commit -m "Fix CORS configuration for production domain"
git push origin main
```

### Step 2: On your VM, pull the latest code and refresh

SSH into your VM and run:

```bash
cd ~/transport/transportwebandmobile/soliflexweb
git pull origin main
./refresh-vm.sh
```

**OR** if you don't have the refresh script, run these commands manually:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Pull latest code
git pull origin main

# Stop PM2 processes
pm2 stop all
pm2 delete all
pm2 flush

# Install backend dependencies (in case helmet/rate-limit need updating)
cd backend
npm install
cd ..

# Rebuild Flutter frontend
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

# Start PM2 processes
pm2 start ecosystem.config.js

# IMPORTANT: Save PM2 configuration so it persists after reboot
pm2 save

# Check status
pm2 list
pm2 logs soliflex-backend --lines 50
```

### Step 3: Verify the fix

1. Check backend logs for errors:
   ```bash
   pm2 logs soliflex-backend --lines 50
   ```

2. Test the backend health endpoint:
   ```bash
   curl http://localhost:3000/health
   ```

3. Check if CORS is working by looking for CORS errors in the logs

### Step 4: If still getting errors

Check the backend logs for the actual error:
```bash
pm2 logs soliflex-backend --lines 100
```

Common issues:
- **Missing dependencies**: Run `cd backend && npm install`
- **Port already in use**: Check with `netstat -tulpn | grep 3000`
- **Permission issues**: Check file permissions
- **Environment variable**: Make sure `NODE_ENV=production` is set if needed

## About `pm2 save`

**Yes, `pm2 save` is important!** It saves the current PM2 process list so that:
- Processes restart automatically after server reboot
- Processes are restored if PM2 crashes
- Your application stays running even after system restarts

Without `pm2 save`, if the server reboots, your applications won't start automatically.

## Quick Fix (if you just need to update CORS without full refresh)

If you just need to update the CORS configuration quickly:

1. Edit `backend/server.js` on the VM
2. Find the `allowedOrigins` array (around line 62)
3. Add: `'https://transport.soliflexpackaging.com'`
4. Restart PM2: `pm2 restart soliflex-backend`
5. Save: `pm2 save`

But it's better to pull the updated code from git.

