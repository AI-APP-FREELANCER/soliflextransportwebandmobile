# Fix 502 Bad Gateway and Departments Dropdown Issues

## Problem Summary

1. **502 Bad Gateway** errors when accessing `/api/departments`
2. Departments dropdown not working on login screen
3. Departments dropdown not working on registration screen
4. Manifest.json syntax error

## Root Causes

1. **Backend Server Not Running**: The 502 error indicates the backend server is not running or not accessible
2. **No Error Handling**: Frontend doesn't show helpful error messages when API fails
3. **No Retry Mechanism**: Users can't retry loading departments when it fails
4. **Manifest.json**: May be a caching issue or serving problem

## Fixes Applied

### 1. Frontend Error Handling (`lib/screens/login_screen.dart`)

- Added loading indicator when departments are loading
- Added error display with retry button when departments fail to load
- Added empty state handling when no departments are available
- User-friendly error messages for 502 and network errors

### 2. Improved Error Messages (`lib/providers/department_provider.dart`)

- Better error message parsing for 502 Bad Gateway errors
- User-friendly messages instead of technical errors
- Clear indication when backend is not responding

### 3. Register Screen Already Has Error Handling

- Register screen already has proper error handling
- No changes needed

## How to Fix on VM

### Step 1: Check if Backend is Running

```bash
# Check PM2 status
pm2 list

# Check if backend is running on port 5000
curl http://localhost:5000/health

# Check backend logs
pm2 logs soliflex-backend --lines 50
```

### Step 2: Start Backend if Not Running

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Start backend
pm2 start ecosystem.config.js --only soliflex-backend

# Or restart if already running
pm2 restart soliflex-backend

# Save configuration
pm2 save
```

### Step 3: Verify Backend is Accessible

```bash
# Test departments endpoint directly
curl http://localhost:5000/api/departments

# Should return JSON with departments array
```

### Step 4: Check Nginx Configuration (if using reverse proxy)

```bash
# Check nginx status
sudo systemctl status nginx

# Test nginx configuration
sudo nginx -t

# Reload nginx if needed
sudo systemctl reload nginx

# Check nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Step 5: Rebuild and Restart Frontend

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons

# Restart frontend
pm2 restart soliflex-frontend
pm2 save
```

### Step 6: Clear Browser Cache

The manifest.json error might be due to cached files. Clear browser cache:
- Chrome/Edge: Ctrl+Shift+Delete → Clear cached images and files
- Or use Incognito/Private mode to test

## Verification

1. **Backend Health Check**:
   ```bash
   curl http://localhost:5000/health
   # Should return: {"status":"ok","message":"Soliflex Backend API is running"}
   ```

2. **Departments Endpoint**:
   ```bash
   curl http://localhost:5000/api/departments
   # Should return JSON with departments array
   ```

3. **Frontend Test**:
   - Open login screen
   - Should see loading indicator, then departments dropdown
   - If error, should see error message with retry button

## Common Issues and Solutions

### Issue: Backend shows as "online" in PM2 but returns 502

**Solution**:
```bash
# Check if port is actually listening
sudo netstat -tulpn | grep 5000

# Check backend logs for errors
pm2 logs soliflex-backend --lines 100

# Restart backend
pm2 restart soliflex-backend
```

### Issue: Nginx returns 502 but backend works on localhost

**Solution**:
- Check nginx proxy_pass configuration points to correct port (5000)
- Check nginx can reach localhost:5000
- Verify nginx error logs

### Issue: Departments dropdown shows but is empty

**Solution**:
- Check browser console for errors
- Verify API response in Network tab
- Check if backend returns departments correctly

### Issue: Manifest.json syntax error

**Solution**:
- Clear browser cache
- Rebuild frontend: `flutter build web --release`
- Check if manifest.json is being served correctly
- Verify manifest.json is valid JSON

## Quick Recovery Script

```bash
#!/bin/bash
echo "=== Fixing 502 and Departments Issues ==="

# 1. Check backend
echo "Checking backend..."
pm2 list | grep soliflex-backend

# 2. Restart backend
echo "Restarting backend..."
pm2 restart soliflex-backend

# 3. Wait for startup
sleep 3

# 4. Test backend
echo "Testing backend..."
curl http://localhost:5000/health

# 5. Test departments
echo "Testing departments endpoint..."
curl http://localhost:5000/api/departments

# 6. Restart frontend
echo "Restarting frontend..."
pm2 restart soliflex-frontend

# 7. Save PM2
pm2 save

echo "=== Done ==="
```

## Expected Behavior After Fix

1. **Login Screen**:
   - Shows loading indicator when departments are loading
   - Shows departments dropdown when loaded successfully
   - Shows error message with retry button if loading fails
   - Dropdown is clickable and functional

2. **Register Screen**:
   - Same behavior as login screen
   - Proper error handling already in place

3. **No More 502 Errors**:
   - Backend is running and accessible
   - API endpoints respond correctly
   - Frontend can load departments successfully

