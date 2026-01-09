# Backend Startup and 502 Error Fix Guide

## Problem Summary

- **502 Bad Gateway** errors when accessing `/api/departments`
- Backend server not starting or not accessible
- Manifest.json syntax error (likely caching issue)

## Root Causes

1. **Backend not running**: PM2 process may have failed to start
2. **Port conflicts**: Another process may be using port 5000
3. **Missing dependencies**: Node modules may not be installed
4. **Build issues**: Frontend build may be incomplete

## Updated refresh-vm.sh Improvements

The refresh script has been significantly improved with:

1. **Port conflict detection and resolution**
2. **Better error handling** (doesn't exit on minor errors)
3. **Comprehensive verification steps**
4. **Backend health checks** with actual HTTP tests
5. **Departments endpoint verification**
6. **Manifest.json validation and copying**
7. **Detailed troubleshooting output**

## Manual Fix Steps (if script doesn't work)

### Step 1: Check Current Status

```bash
# Check PM2 status
pm2 list

# Check if backend is running
curl http://localhost:5000/health

# Check backend logs
pm2 logs soliflex-backend --lines 50
```

### Step 2: Kill Port Conflicts

```bash
# Find what's using port 5000
sudo lsof -i :5000
# Or
sudo netstat -tulpn | grep 5000

# Kill the process (replace PID with actual process ID)
sudo kill -9 <PID>
```

### Step 3: Stop All PM2 Processes

```bash
pm2 stop all
pm2 delete all
pm2 flush
```

### Step 4: Verify Backend Files

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if server.js exists
ls -la backend/server.js

# Check if node_modules exists
ls -la backend/node_modules
```

### Step 5: Install Backend Dependencies

```bash
cd backend
npm install
cd ..
```

### Step 6: Test Backend Manually

```bash
cd backend
node server.js
# Should see: "Server is running on port 5000 (production mode)"
# Press Ctrl+C to stop
```

### Step 7: Start with PM2

```bash
cd ~/transport/transportwebandmobile/soliflexweb
pm2 start ecosystem.config.js
pm2 save
```

### Step 8: Verify Backend is Running

```bash
# Wait a few seconds
sleep 5

# Check PM2 status
pm2 list

# Test health endpoint
curl http://localhost:5000/health

# Test departments endpoint
curl http://localhost:5000/api/departments
```

### Step 9: Check Backend Logs

```bash
# View recent logs
pm2 logs soliflex-backend --lines 50

# Look for errors like:
# - "EADDRINUSE" (port in use)
# - "Cannot find module" (missing dependencies)
# - "SyntaxError" (code errors)
```

## Common Issues and Solutions

### Issue 1: "EADDRINUSE: address already in use :::5000"

**Solution**:
```bash
# Find and kill process on port 5000
sudo lsof -ti:5000 | xargs sudo kill -9

# Or use fuser
sudo fuser -k 5000/tcp

# Then restart
pm2 restart soliflex-backend
```

### Issue 2: "Cannot find module 'express'"

**Solution**:
```bash
cd backend
rm -rf node_modules
npm install
cd ..
pm2 restart soliflex-backend
```

### Issue 3: Backend starts but returns 502

**Possible causes**:
1. Nginx proxy misconfiguration
2. Backend crashed after startup
3. Backend listening on wrong port

**Solution**:
```bash
# Check if backend is actually listening
sudo netstat -tulpn | grep 5000

# Check backend logs for errors
pm2 logs soliflex-backend --lines 100

# Test backend directly (bypass nginx)
curl http://localhost:5000/health

# If direct works but nginx doesn't, check nginx config
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### Issue 4: Manifest.json Syntax Error

**Solution**:
```bash
# Rebuild frontend
cd ~/transport/transportwebandmobile/soliflexweb
flutter clean
flutter build web --release

# Verify manifest.json exists
ls -la build/web/manifest.json

# Validate JSON
node -e "JSON.parse(require('fs').readFileSync('build/web/manifest.json'))"

# Restart frontend
pm2 restart soliflex-frontend
```

## Quick Recovery Script

```bash
#!/bin/bash
echo "=== Quick Backend Recovery ==="

# Kill port conflicts
sudo lsof -ti:5000 | xargs sudo kill -9 2>/dev/null || true
sudo lsof -ti:8081 | xargs sudo kill -9 2>/dev/null || true

# Stop PM2
pm2 stop all
pm2 delete all

# Install dependencies
cd ~/transport/transportwebandmobile/soliflexweb/backend
npm install
cd ..

# Start PM2
pm2 start ecosystem.config.js
pm2 save

# Wait and test
sleep 5
curl http://localhost:5000/health
curl http://localhost:5000/api/departments

echo "=== Done ==="
```

## Verification Checklist

After running the refresh script or manual steps:

- [ ] `pm2 list` shows `soliflex-backend` as `online`
- [ ] `curl http://localhost:5000/health` returns `{"status":"ok",...}`
- [ ] `curl http://localhost:5000/api/departments` returns JSON with departments array
- [ ] `pm2 logs soliflex-backend` shows "Server is running on port 5000"
- [ ] No errors in backend logs
- [ ] Frontend can load departments dropdown

## Next Steps

1. Run the updated `refresh-vm.sh` script
2. If issues persist, follow manual steps above
3. Check logs for specific error messages
4. Verify nginx configuration if using reverse proxy

