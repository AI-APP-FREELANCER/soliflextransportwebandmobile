# Fix Port Conflict and CORS Error

## Problem
1. Port 3000 is already in use by `sol-emp-backend`
2. CORS error because the wrong backend is running

## Solution

### Step 1: Stop the conflicting backend

On your VM, run:

```bash
# Check what's using port 3000
pm2 list

# Stop the other backend (sol-emp-backend)
pm2 stop sol-emp-backend

# Or if you don't need it, delete it
pm2 delete sol-emp-backend
```

### Step 2: Make sure you have the latest code

```bash
cd ~/transport/transportwebandmobile/soliflexweb
git pull origin main
```

### Step 3: Verify backend dependencies are installed

```bash
cd backend
npm install
cd ..
```

### Step 4: Stop and restart soliflex-backend properly

```bash
# Stop soliflex-backend
pm2 stop soliflex-backend
pm2 delete soliflex-backend

# Wait a moment
sleep 2

# Start it again
pm2 start ecosystem.config.js

# Save the configuration
pm2 save
```

### Step 5: Verify it's running

```bash
# Check status
pm2 list

# Check logs (should see "Server is running on port 3000")
pm2 logs soliflex-backend --lines 20

# Test the backend
curl http://localhost:3000/health
```

### Step 6: If port is still in use

If port 3000 is still in use after stopping sol-emp-backend:

```bash
# Find what's using port 3000
sudo lsof -i :3000
# Or
sudo netstat -tulpn | grep 3000

# Kill the process (replace PID with actual process ID)
sudo kill -9 <PID>
```

Then restart:
```bash
pm2 restart soliflex-backend
pm2 save
```

## Alternative: Use Different Ports

If you need both backends running, you can configure them to use different ports:

1. Edit `ecosystem.config.js` to use a different port for one backend
2. Update nginx configuration to proxy to the correct port
3. Restart both backends

But for now, the simplest solution is to stop `sol-emp-backend` if you don't need it.

