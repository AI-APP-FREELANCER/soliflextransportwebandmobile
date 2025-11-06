# Start the Application

## Step-by-Step Commands

### Step 1: Restart PM2 Apps

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop previous apps
pm2 stop all
pm2 delete all

# Start apps with new build
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Check status
pm2 list
```

### Step 2: Check PM2 Logs

```bash
# View all logs
pm2 logs

# View frontend logs specifically
pm2 logs soliflex-frontend --lines 30

# View backend logs
pm2 logs soliflex-backend --lines 30
```

### Step 3: Verify Ports are Listening

```bash
# Check if backend is listening on port 3000
sudo netstat -tulpn | grep 3000

# Check if frontend is listening on port 8081
sudo netstat -tulpn | grep 8081

# Alternative check
sudo lsof -i :3000
sudo lsof -i :8081
```

### Step 4: Test Locally

```bash
# Test backend health endpoint
curl http://localhost:3000/health

# Test frontend (should return HTML)
curl http://localhost:8081/ | head -20

# Test if main.dart.js is accessible
curl -I http://localhost:8081/main.dart.js

# Test if manifest.json is accessible
curl http://localhost:8081/manifest.json
```

### Step 5: Verify Files are Being Served

```bash
# Check if main.dart.js is accessible
curl http://localhost:8081/main.dart.js | head -5

# Should return JavaScript code, not 404
```

---

## Complete Startup Sequence

Run this complete sequence:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# 1. Stop and delete previous apps
echo "Stopping previous apps..."
pm2 stop all
pm2 delete all

# 2. Start apps
echo "Starting apps..."
pm2 start ecosystem.config.js

# 3. Save configuration
echo "Saving PM2 configuration..."
pm2 save

# 4. Check status
echo ""
echo "=== PM2 Status ==="
pm2 list

# 5. Check logs
echo ""
echo "=== Recent Logs ==="
pm2 logs --lines 10

# 6. Test services
echo ""
echo "=== Testing Services ==="
echo "Testing backend..."
curl -s http://localhost:3000/health && echo "" || echo "Backend not responding"

echo "Testing frontend..."
curl -s -I http://localhost:8081/ | head -1 || echo "Frontend not responding"

echo "Testing main.dart.js..."
curl -s -I http://localhost:8081/main.dart.js | head -1 || echo "main.dart.js not accessible"
```

---

## Verify Everything is Working

### Check PM2 Status

```bash
pm2 list
```

You should see:
- `soliflex-backend` - status: `online`
- `soliflex-frontend` - status: `online`

### Check Logs for Errors

```bash
# View frontend logs
pm2 logs soliflex-frontend --lines 20

# View backend logs
pm2 logs soliflex-backend --lines 20
```

### Test from Browser

1. **Backend**: Open `http://YOUR_VM_IP:3000/health`
   - Should return: `{"status":"ok","message":"Soliflex Backend API is running"}`

2. **Frontend**: Open `http://YOUR_VM_IP:8081`
   - Should load the Flutter app
   - Check browser console (F12) - should NOT see 404 errors

---

## Troubleshooting

### If PM2 apps don't start:

```bash
# Check PM2 logs for errors
pm2 logs --err

# Check if ports are already in use
sudo lsof -i :3000
sudo lsof -i :8081

# If ports are in use, kill the processes
sudo kill -9 <PID>
```

### If frontend shows 404 errors:

```bash
# Verify build files exist
ls -la build/web/main.dart.js
ls -la build/web/manifest.json

# Check PM2 is serving from correct directory
pm2 info soliflex-frontend

# Restart frontend
pm2 restart soliflex-frontend
pm2 logs soliflex-frontend
```

### If backend doesn't respond:

```bash
# Check backend logs
pm2 logs soliflex-backend

# Test backend directly
cd ~/transport/transportwebandmobile/soliflexweb/backend
node server.js
# Press Ctrl+C to stop
```

---

## Access URLs

After everything is running:

- **Backend API**: `http://YOUR_VM_IP:3000`
- **Frontend**: `http://YOUR_VM_IP:8081`
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

# View specific app info
pm2 info soliflex-backend
pm2 info soliflex-frontend
```

