# Fix 404 Errors for main.dart.js and manifest.json

## Problem
- `main.dart.js:1 Failed to load resource: the server responded with a status of 404 (Not Found)`
- `manifest.json:1 Failed to load resource: the server responded with a status of 404 (Not Found)`

## Diagnosis Steps (Run on Ubuntu VM)

### Step 1: Check if build/web directory exists and has files

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if build/web exists
ls -la build/web/

# Check for specific files
ls -la build/web/main.dart.js
ls -la build/web/manifest.json
ls -la build/web/index.html
```

**Expected output:** You should see these files:
- `index.html`
- `main.dart.js` (or `main.dart.js.gz`)
- `flutter_bootstrap.js`
- `manifest.json`
- `assets/` directory

### Step 2: Check PM2 logs

```bash
# Check frontend logs
pm2 logs soliflex-frontend --lines 50

# Check if http-server is running correctly
pm2 info soliflex-frontend
```

### Step 3: Test if files are accessible locally

```bash
# Test from VM
curl http://localhost:8081/
curl http://localhost:8081/main.dart.js
curl http://localhost:8081/manifest.json
```

---

## Solutions

### Solution 1: Rebuild Flutter Web (Most Likely Fix)

The build might be incomplete or corrupted. Rebuild it:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Clean previous build
flutter clean

# Get dependencies
flutter pub get

# Rebuild with service worker disabled
flutter build web --release --pwa-strategy=none

# Verify build output
ls -la build/web/
ls -la build/web/main.dart.js
ls -la build/web/manifest.json

# Restart PM2
pm2 stop soliflex-frontend
pm2 delete soliflex-frontend
pm2 start ecosystem.config.js
pm2 save
```

### Solution 2: Check if web directory exists in project root

If the `web/` directory doesn't exist, Flutter won't build properly:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if web directory exists
ls -la web/

# If it doesn't exist, create it
flutter create . --platforms web

# Then rebuild
flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none
```

### Solution 3: Verify http-server is serving from correct directory

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check current directory
pwd
# Should be: /home/soliflexuser/transport/transportwebandmobile/soliflexweb

# Check if build/web exists from this directory
ls -la build/web/

# Manually test http-server
npx http-server build/web -p 8081 -c-1 --cors
# Press Ctrl+C to stop after testing

# If manual test works, restart PM2
pm2 restart soliflex-frontend
```

### Solution 4: Check PM2 working directory

PM2 might be running from the wrong directory:

```bash
# Check PM2 process details
pm2 info soliflex-frontend

# Check the cwd (current working directory)
# It should point to: /home/soliflexuser/transport/transportwebandmobile/soliflexweb

# If wrong, stop and restart from correct directory
cd ~/transport/transportwebandmobile/soliflexweb
pm2 stop all
pm2 delete all
pm2 start ecosystem.config.js
pm2 save
```

### Solution 5: Check file permissions

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check permissions
ls -la build/web/

# If files don't have read permissions, fix them
chmod -R 755 build/web/
```

---

## Complete Fix Sequence

Run these commands in order:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# 1. Ensure web directory exists
if [ ! -d "web" ]; then
    echo "Creating web directory..."
    flutter create . --platforms web
fi

# 2. Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none

# 3. Verify build output
echo "Checking build output..."
ls -la build/web/ | head -20
ls -la build/web/main.dart.js
ls -la build/web/manifest.json

# 4. Restart PM2
pm2 stop soliflex-frontend
pm2 delete soliflex-frontend
pm2 start ecosystem.config.js
pm2 save

# 5. Check logs
pm2 logs soliflex-frontend --lines 20

# 6. Test locally
curl http://localhost:8081/ | head -20
curl -I http://localhost:8081/main.dart.js
curl -I http://localhost:8081/manifest.json
```

---

## Verify the Fix

After running the fix:

1. **Check browser console** - Should not see 404 errors
2. **Test from command line:**
   ```bash
   curl http://localhost:8081/main.dart.js | head -5
   curl http://localhost:8081/manifest.json
   ```

3. **Check PM2 status:**
   ```bash
   pm2 list
   pm2 logs soliflex-frontend
   ```

4. **Access from browser:**
   - Open: `http://YOUR_VM_IP:8081`
   - Check browser console (F12) - should not see 404 errors
   - App should load

---

## Common Issues

### Issue: `main.dart.js` not found but `main.dart.js.gz` exists

Some Flutter builds create gzipped files. http-server should serve them automatically, but if not:

```bash
# Check if gzipped files exist
ls -la build/web/*.gz

# http-server should handle .gz files automatically
# If not, you may need to configure it
```

### Issue: Files exist but still getting 404

This could be a path issue. Check:

```bash
# Verify http-server is serving from build/web
pm2 info soliflex-frontend | grep "script path"

# The args should be: http-server build/web -p 8081 -c-1 --cors
```

### Issue: Build succeeds but files are in wrong location

```bash
# Check where Flutter built the files
find . -name "main.dart.js" -type f
find . -name "manifest.json" -type f

# If files are in a different location, update ecosystem.config.js
```

---

## Quick Test

To quickly test if the issue is with the build or the server:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Stop PM2
pm2 stop soliflex-frontend

# Manually start http-server
cd build/web
npx http-server . -p 8081 -c-1 --cors

# In another terminal, test:
curl http://localhost:8081/main.dart.js | head -5

# If this works, the issue is with PM2 configuration
# If this doesn't work, the issue is with the Flutter build
```

