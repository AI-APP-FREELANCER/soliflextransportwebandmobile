# VM Code Refresh Guide

## Step-by-Step Process to Refresh Code on VM

### 1. Verify Code is Pulled from Git
```bash
cd ~/transport/transportwebandmobile/soliflexweb
git status
git pull origin main
```

### 2. Verify the Changed File Exists and Has Updates
```bash
# Check if orderRoutes.js has the new code
grep -n "CRITICAL FIX: Update order's trip_segments BEFORE checking completion" backend/routes/orderRoutes.js
grep -n "fix-completed-orders" backend/routes/orderRoutes.js
```

### 3. Stop PM2 Processes
```bash
pm2 stop all
# Or stop individually:
pm2 stop soliflex-backend
pm2 stop soliflex-frontend
```

### 4. Clear PM2 Cache (if needed)
```bash
pm2 flush
```

### 5. Verify File Permissions
```bash
ls -la backend/routes/orderRoutes.js
# Should show readable file
```

### 6. Restart Backend with Fresh Start
```bash
# Delete and recreate the process
pm2 delete soliflex-backend
cd ~/transport/transportwebandmobile/soliflexweb
pm2 start ecosystem.config.js --only soliflex-backend
```

### 7. Check PM2 Logs to Verify
```bash
pm2 logs soliflex-backend --lines 50
# Look for server startup message
```

### 8. Test the Endpoint
```bash
curl http://localhost:3000/health
# Should return: {"status":"ok","message":"Soliflex Backend API is running"}
```

## Alternative: Full Restart Method

If the above doesn't work, try a complete restart:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop everything
pm2 stop all
pm2 delete all

# Verify code is updated
git pull origin main
cat backend/routes/orderRoutes.js | grep -A 5 "fix-completed-orders"

# Restart from ecosystem config
pm2 start ecosystem.config.js

# Save PM2 config
pm2 save

# Check status
pm2 list
pm2 logs soliflex-backend --lines 20
```

## Verify Changes Are Applied

Test the new endpoint:
```bash
curl -X POST http://localhost:3000/api/fix-completed-orders
```

Or check logs for the new logging:
```bash
pm2 logs soliflex-backend | grep "Workflow Status Check"
```

