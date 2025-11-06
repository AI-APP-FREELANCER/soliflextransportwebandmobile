# Fix Flutter Web Service Worker and 404 Errors

## Problem
- Service Worker API unavailable (requires HTTPS)
- 404 errors for main.dart.js, favicon.png, manifest.json
- App not displaying

## Solution

Run these commands **on your Ubuntu VM**:

### Step 1: Rebuild Flutter Web with Service Worker Disabled

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Clean previous build
flutter clean

# Rebuild with service worker disabled (for HTTP deployment)
flutter build web --release --pwa-strategy=none
```

### Step 2: Verify Build Output

```bash
# Check if build/web directory exists and has files
ls -la build/web/

# You should see:
# - index.html
# - main.dart.js
# - flutter_bootstrap.js
# - assets/ (directory)
# - Other files
```

### Step 3: Check if web/index.html exists in project root

```bash
# Check if web directory exists in project root
ls -la web/

# If it doesn't exist, create it
flutter create . --platforms web
```

### Step 4: Restart PM2 Apps

```bash
# Stop apps
pm2 stop all
pm2 delete all

# Start apps again
pm2 start ecosystem.config.js

# Check status
pm2 list
pm2 logs
```

### Step 5: Verify Files Are Being Served

```bash
# Test from VM
curl http://localhost:4000/
curl http://localhost:4000/index.html
curl http://localhost:4000/main.dart.js

# Check if files exist
ls -la build/web/main.dart.js
ls -la build/web/index.html
```

---

## Alternative: Build Without Service Worker (Recommended for HTTP)

If `--pwa-strategy=none` doesn't work, you can manually disable service worker:

### Step 1: Check if web/index.html exists

```bash
cd ~/transport/transportwebandmobile/soliflexweb
ls -la web/
```

### Step 2: If web directory doesn't exist, create it

```bash
flutter create . --platforms web
```

### Step 3: Modify web/index.html to disable service worker

You may need to edit the build output or the source web/index.html. But first, try rebuilding with the flag above.

### Step 4: Rebuild

```bash
flutter clean
flutter pub get
flutter build web --release --pwa-strategy=none
```

---

## Complete Fix Command Sequence

```bash
cd ~/transport/transportwebandmobile/soliflexweb && \
flutter clean && \
flutter pub get && \
flutter build web --release --pwa-strategy=none && \
ls -la build/web/ && \
pm2 stop all && \
pm2 delete all && \
pm2 start ecosystem.config.js && \
pm2 logs --lines 20
```

---

## Verify the Fix

After rebuilding and restarting:

1. **Check PM2 logs:**
   ```bash
   pm2 logs soliflex-frontend
   ```

2. **Test from browser:**
   - Open: `http://YOUR_VM_IP:4000`
   - Check browser console - should not see service worker errors
   - App should load

3. **Test from command line:**
   ```bash
   curl http://localhost:4000/
   curl http://localhost:4000/main.dart.js
   ```

---

## If Still Getting 404 Errors

### Check http-server is serving from correct directory:

```bash
# Check PM2 process details
pm2 info soliflex-frontend

# Check if build/web exists
ls -la build/web/

# Manually test http-server
cd ~/transport/transportwebandmobile/soliflexweb
npx http-server build/web -p 4000 -c-1 --cors
# Press Ctrl+C to stop
```

### Verify ecosystem.config.js path:

The ecosystem.config.js should be serving from `build/web`:
```javascript
args: 'http-server build/web -p 4000 -c-1 --cors'
```

Make sure you're running PM2 from the project root where ecosystem.config.js is located.

---

## Notes

- `--pwa-strategy=none` disables Progressive Web App features including service workers
- This is necessary when serving over HTTP (not HTTPS)
- Service workers require HTTPS or localhost
- The 404 errors suggest files aren't being found - rebuilding should fix this

