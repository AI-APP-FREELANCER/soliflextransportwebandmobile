# Troubleshooting 500 Error on VM

## Step 1: Check Backend Logs

The most important step is to see what error the backend is actually throwing:

```bash
pm2 logs soliflex-backend --lines 100
```

This will show you the actual error. Common issues:

### Issue 1: Missing Dependencies
**Error**: `Cannot find module 'helmet'` or `Cannot find module 'express-rate-limit'`

**Fix**:
```bash
cd ~/transport/transportwebandmobile/soliflexweb/backend
npm install
pm2 restart soliflex-backend
pm2 save
```

### Issue 2: Server Not Running
**Error**: Connection refused or no response

**Fix**:
```bash
pm2 list
# If backend is not running:
pm2 start ecosystem.config.js
pm2 save
```

### Issue 3: Syntax Error in server.js
**Error**: Syntax errors in logs

**Fix**: Check if server.js has valid syntax:
```bash
cd ~/transport/transportwebandmobile/soliflexweb/backend
node -c server.js
```

### Issue 4: Port Already in Use
**Error**: Port 3000 already in use

**Fix**:
```bash
# Check what's using port 3000
sudo netstat -tulpn | grep 3000
# Or
sudo lsof -i :3000

# Kill the process or restart PM2
pm2 restart soliflex-backend
```

## Step 2: Verify Backend is Running

Test the backend directly:

```bash
# Test health endpoint
curl http://localhost:3000/health

# Test from the server itself
curl http://localhost:3000/api/departments
```

If these fail, the backend is not running or has an error.

## Step 3: Check PM2 Status

```bash
pm2 list
pm2 status
```

You should see:
- `soliflex-backend` - status: online
- `soliflex-frontend` - status: online

If status is `errored` or `stopped`, check logs:
```bash
pm2 logs soliflex-backend --err
```

## Step 4: Verify Dependencies Installed

```bash
cd ~/transport/transportwebandmobile/soliflexweb/backend
npm list helmet express-rate-limit
```

If they're not installed:
```bash
npm install
```

## Step 5: Test Backend Startup Manually

Stop PM2 and test if server starts:

```bash
pm2 stop all
cd ~/transport/transportwebandmobile/soliflexweb/backend
node server.js
```

If it starts successfully, you'll see:
```
Server is running on port 3000 (production mode)
```

If there's an error, you'll see it in the console. Common errors:
- Missing modules
- Syntax errors
- Port conflicts

Press Ctrl+C to stop, then restart PM2:
```bash
pm2 start ecosystem.config.js
pm2 save
```

## Step 6: Check Environment Variables

```bash
# Check if NODE_ENV is set
echo $NODE_ENV

# If not set or wrong, set it in ecosystem.config.js or export it
export NODE_ENV=production
```

## Step 7: Verify File Permissions

```bash
cd ~/transport/transportwebandmobile/soliflexweb
ls -la backend/server.js
ls -la ecosystem.config.js
```

Files should be readable by the user running PM2.

## Step 8: Full Restart Procedure

If nothing else works, do a complete restart:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop everything
pm2 stop all
pm2 delete all

# Pull latest code
git pull origin main

# Install dependencies
cd backend
npm install
cd ..

# Rebuild frontend
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

# Start PM2
pm2 start ecosystem.config.js
pm2 save

# Check status
pm2 list
pm2 logs soliflex-backend --lines 50
```

## Step 9: Check Nginx Configuration

If backend is running but still getting 500 errors, check nginx:

```bash
# Test nginx config
sudo nginx -t

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx if needed
sudo systemctl restart nginx
```

## Common Error Messages and Solutions

### "Cannot find module 'helmet'"
```bash
cd backend && npm install && pm2 restart soliflex-backend
```

### "EADDRINUSE: address already in use :::3000"
```bash
pm2 restart soliflex-backend
# Or find and kill the process
sudo lsof -i :3000
sudo kill -9 <PID>
```

### "Error: Not allowed by CORS"
- Check that `https://transport.soliflexpackaging.com` is in allowedOrigins in server.js
- Verify NODE_ENV is set correctly

### "SyntaxError: Unexpected token"
- Check server.js for syntax errors
- Run `node -c server.js` to validate

## Getting Help

If you're still stuck, provide:
1. Output of `pm2 logs soliflex-backend --lines 100`
2. Output of `pm2 list`
3. Output of `curl http://localhost:3000/health`
4. Output of `node -c backend/server.js`

