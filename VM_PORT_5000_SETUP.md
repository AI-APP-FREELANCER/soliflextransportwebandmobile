# Setup Transport App - Port 5000 (Backend) and 8081 (Frontend)

## Port Configuration

- **Backend**: Port 5000 ✅
- **Frontend**: Port 8081 ✅

## Changes Made

1. ✅ Updated `ecosystem.config.js` - PORT set to 5000
2. ✅ Updated `backend/server.js` - Default port changed to 5000
3. ✅ Updated `NGINX_CONFIG_GUIDE.md` - Documentation updated

## Steps to Apply on VM

### Step 1: Pull Latest Code

```bash
cd ~/transport/transportwebandmobile/soliflexweb
git pull origin main
```

### Step 2: Update Nginx Configuration

You need to update your nginx config to proxy to port 5000 instead of 3000/4000.

Edit your nginx config file (usually `/etc/nginx/sites-available/default` or `/etc/nginx/nginx.conf`):

```bash
sudo nano /etc/nginx/sites-available/default
```

Find the lines that say:
```nginx
proxy_pass http://localhost:3000;
```
or
```nginx
proxy_pass http://localhost:4000;
```

Change them to:
```nginx
proxy_pass http://localhost:5000;
```

This should be in:
- `location /api/` block
- `location /health` block (if you have one)

**Example nginx configuration:**

```nginx
server {
    listen 443 ssl http2;
    server_name transport.soliflexpackaging.com;
    
    # SSL Configuration
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Backend API - All /api/* routes go to backend (port 5000)
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # CORS headers (if needed)
        add_header Access-Control-Allow-Origin * always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Content-Type, Authorization" always;
        
        # Handle preflight requests
        if ($request_method = OPTIONS) {
            return 204;
        }
    }
    
    # Health check endpoint (no /api prefix)
    location /health {
        proxy_pass http://localhost:5000;
    }
    
    # Frontend (all other routes) - Port 8081
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Step 3: Test and Reload Nginx

```bash
# Test nginx configuration
sudo nginx -t

# If test passes, reload nginx
sudo systemctl reload nginx
# Or
sudo service nginx reload
```

### Step 4: Restart Backend on Port 5000

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop the old backend (if running on wrong port)
pm2 stop soliflex-backend
pm2 delete soliflex-backend

# Start with new configuration (port 5000)
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save
```

### Step 5: Verify Everything is Working

```bash
# Check PM2 status
pm2 list

# Check backend logs (should show port 5000)
pm2 logs soliflex-backend --lines 20

# Test backend directly
curl http://localhost:5000/health

# Test frontend directly
curl http://localhost:8081

# Test through nginx (from VM)
curl http://localhost/api/departments
curl http://localhost/health

# Test from outside (if accessible)
curl https://transport.soliflexpackaging.com/api/departments
```

## Expected Results

- `pm2 list` should show:
  - `soliflex-backend` as `online` (port 5000)
  - `soliflex-frontend` as `online` (port 8081)
- Backend logs should show: "Server is running on port 5000 (production mode)"
- `curl http://localhost:5000/health` should return: `{"status":"ok",...}`
- `curl http://localhost:8081` should return HTML (frontend)
- No more port conflict errors
- Login should work without CORS errors

## Port Summary

- **sol-emp-backend**: Port 3000 (employee management app)
- **soliflex-backend**: Port 5000 (transport app) ✅
- **soliflex-frontend**: Port 8081 (transport frontend) ✅

## Troubleshooting

### If backend still shows wrong port in logs:

```bash
# Make sure you pulled the latest code
git pull origin main

# Check ecosystem.config.js has PORT: 5000
cat ecosystem.config.js | grep PORT

# Delete and restart
pm2 delete soliflex-backend
pm2 start ecosystem.config.js
pm2 save

# Check logs
pm2 logs soliflex-backend --lines 10
```

### If nginx still proxies to wrong port:

```bash
# Check nginx config
sudo nginx -t

# View current nginx config
sudo cat /etc/nginx/sites-available/default | grep proxy_pass

# Make sure it shows port 5000, then reload
sudo systemctl reload nginx
```

### If port 5000 is already in use:

```bash
# Check what's using port 5000
sudo lsof -i :5000
# Or
sudo netstat -tulpn | grep 5000

# If needed, kill the process or use a different port
```

### If frontend (8081) is not accessible:

```bash
# Check if frontend is running
pm2 list | grep soliflex-frontend

# Check frontend logs
pm2 logs soliflex-frontend --lines 20

# Restart frontend if needed
pm2 restart soliflex-frontend
```

## Quick Reference Commands

```bash
# View all PM2 processes
pm2 list

# View backend logs
pm2 logs soliflex-backend

# View frontend logs
pm2 logs soliflex-frontend

# Restart both
pm2 restart all

# Stop both
pm2 stop all

# Start both
pm2 start ecosystem.config.js

# Save PM2 config
pm2 save

# Test backend
curl http://localhost:5000/health

# Test frontend
curl http://localhost:8081
```

