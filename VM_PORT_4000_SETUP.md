# Setup Transport Backend on Port 4000

## Changes Made

1. ✅ Updated `ecosystem.config.js` - PORT set to 4000
2. ✅ Updated `backend/server.js` - Default port changed to 4000
3. ✅ Updated `NGINX_CONFIG_GUIDE.md` - Documentation updated

## Steps to Apply on VM

### Step 1: Pull Latest Code

```bash
cd ~/transport/transportwebandmobile/soliflexweb
git pull origin main
```

### Step 2: Update Nginx Configuration

You need to update your nginx config to proxy to port 4000 instead of 3000.

Edit your nginx config file (usually `/etc/nginx/sites-available/default` or `/etc/nginx/nginx.conf`):

```bash
sudo nano /etc/nginx/sites-available/default
```

Find the lines that say:
```nginx
proxy_pass http://localhost:3000;
```

Change them to:
```nginx
proxy_pass http://localhost:4000;
```

This should be in:
- `location /api/` block
- `location /health` block (if you have one)

### Step 3: Test and Reload Nginx

```bash
# Test nginx configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx
# Or
sudo service nginx reload
```

### Step 4: Restart Backend on Port 4000

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop the old backend (if running on wrong port)
pm2 stop soliflex-backend
pm2 delete soliflex-backend

# Start with new configuration (port 4000)
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save
```

### Step 5: Verify Everything is Working

```bash
# Check PM2 status
pm2 list

# Check backend logs
pm2 logs soliflex-backend --lines 20

# Test backend directly
curl http://localhost:4000/health

# Test through nginx (from VM)
curl http://localhost/api/departments
# Or from outside:
curl https://transport.soliflexpackaging.com/api/departments
```

## Expected Results

- `pm2 list` should show `soliflex-backend` as `online`
- Backend logs should show: "Server is running on port 4000 (production mode)"
- `curl http://localhost:4000/health` should return: `{"status":"ok",...}`
- No more port conflict errors
- Login should work without CORS errors

## Port Summary

- **sol-emp-backend**: Port 3000 (employee management app)
- **soliflex-backend**: Port 4000 (transport app) ✅
- **soliflex-frontend**: Port 8081 (transport frontend)

## Troubleshooting

### If backend still shows port 3000 in logs:

```bash
# Make sure you pulled the latest code
git pull origin main

# Delete and restart
pm2 delete soliflex-backend
pm2 start ecosystem.config.js
pm2 save
```

### If nginx still proxies to wrong port:

```bash
# Check nginx config
sudo nginx -t

# View current nginx config
sudo cat /etc/nginx/sites-available/default | grep proxy_pass

# Make sure it shows port 4000, then reload
sudo systemctl reload nginx
```

### If port 4000 is already in use:

```bash
# Check what's using port 4000
sudo lsof -i :4000
# Or
sudo netstat -tulpn | grep 4000

# If needed, kill the process or use a different port
```

