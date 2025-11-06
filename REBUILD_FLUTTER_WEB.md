# Rebuild Flutter Web - Step by Step

## Problem
`build/web/main.dart.js` doesn't exist - Flutter web build is missing or incomplete.

## Step-by-Step Fix

### Step 1: Check Current State

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if build directory exists
ls -la build/

# Check if build/web exists
ls -la build/web/ 2>/dev/null || echo "build/web does not exist"

# Check if web directory exists in project root
ls -la web/
```

### Step 2: Ensure Web Platform is Configured

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if web directory exists
if [ ! -d "web" ]; then
    echo "Creating web directory..."
    flutter create . --platforms web
fi

# Verify web directory was created
ls -la web/
# Should see: index.html, manifest.json, icons/
```

### Step 3: Clean Previous Builds

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Clean Flutter build
flutter clean

# Remove build directory if it exists
rm -rf build/

# Verify it's gone
ls -la build/ 2>/dev/null || echo "Build directory cleaned"
```

### Step 4: Get Flutter Dependencies

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Get dependencies
flutter pub get

# Verify no errors
echo "Dependencies installed"
```

### Step 5: Build Flutter Web

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Build Flutter web (release mode, no service worker)
flutter build web --release --pwa-strategy=none

# Wait for build to complete - this may take a few minutes
# Look for: "Compiling lib/main.dart for the Web..."
# And: "Built build/web"
```

### Step 6: Verify Build Output

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if build/web exists
if [ -d "build/web" ]; then
    echo "✓ build/web directory exists"
    ls -la build/web/
else
    echo "✗ build/web directory does NOT exist - build failed!"
    exit 1
fi

# Check for main.dart.js
if [ -f "build/web/main.dart.js" ]; then
    echo "✓ main.dart.js exists"
    ls -lh build/web/main.dart.js
else
    echo "✗ main.dart.js does NOT exist"
    echo "Checking for alternative files:"
    ls -la build/web/*.js 2>/dev/null || echo "No .js files found"
fi

# Check for other required files
echo "Checking required files:"
ls -la build/web/index.html 2>/dev/null && echo "✓ index.html exists" || echo "✗ index.html missing"
ls -la build/web/manifest.json 2>/dev/null && echo "✓ manifest.json exists" || echo "✗ manifest.json missing"
ls -la build/web/flutter_bootstrap.js 2>/dev/null && echo "✓ flutter_bootstrap.js exists" || echo "✗ flutter_bootstrap.js missing"
```

### Step 7: If Build Fails, Check for Errors

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Try building with verbose output
flutter build web --release --pwa-strategy=none --verbose

# Look for error messages in the output
```

---

## Complete Rebuild Sequence

Run this complete sequence:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# 1. Ensure web platform is configured
if [ ! -d "web" ]; then
    echo "Creating web directory..."
    flutter create . --platforms web
fi

# 2. Clean everything
echo "Cleaning previous builds..."
flutter clean
rm -rf build/

# 3. Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# 4. Build Flutter web
echo "Building Flutter web (this may take a few minutes)..."
flutter build web --release --pwa-strategy=none

# 5. Verify build
echo ""
echo "=== Build Verification ==="
if [ -d "build/web" ]; then
    echo "✓ build/web directory exists"
    echo ""
    echo "Files in build/web:"
    ls -lh build/web/ | head -20
    
    echo ""
    if [ -f "build/web/main.dart.js" ]; then
        echo "✓ main.dart.js exists ($(du -h build/web/main.dart.js | cut -f1))"
    else
        echo "✗ main.dart.js NOT FOUND"
        echo "Checking for .js files:"
        find build/web -name "*.js" -type f
    fi
    
    if [ -f "build/web/index.html" ]; then
        echo "✓ index.html exists"
    else
        echo "✗ index.html NOT FOUND"
    fi
    
    if [ -f "build/web/manifest.json" ]; then
        echo "✓ manifest.json exists"
    else
        echo "✗ manifest.json NOT FOUND"
    fi
else
    echo "✗ BUILD FAILED - build/web directory does not exist"
    echo "Check the error messages above"
    exit 1
fi
```

---

## Troubleshooting Build Errors

### If build fails with compilation errors:

```bash
# Check Flutter version
flutter --version

# Check Flutter doctor
flutter doctor

# Try building with more verbose output
flutter build web --release --pwa-strategy=none --verbose 2>&1 | tee build.log

# Check the log file
cat build.log | grep -i error
```

### If build succeeds but files are in wrong location:

```bash
# Find where main.dart.js actually is
find . -name "main.dart.js" -type f

# Find where manifest.json is
find . -name "manifest.json" -type f

# If files are in a different location, you may need to:
# 1. Check Flutter version compatibility
# 2. Update ecosystem.config.js to point to correct location
```

### If web directory doesn't exist:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Create web directory
flutter create . --platforms web

# Verify it was created
ls -la web/

# Should see:
# - index.html
# - manifest.json
# - icons/ (directory)
```

---

## After Successful Build

Once the build is successful and you see `main.dart.js`:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Restart PM2
pm2 stop soliflex-frontend
pm2 delete soliflex-frontend
pm2 start ecosystem.config.js
pm2 save

# Check logs
pm2 logs soliflex-frontend --lines 20

# Test locally
curl http://localhost:8081/main.dart.js | head -5
```

---

## Expected Build Output

After a successful build, `build/web/` should contain:

```
build/web/
├── index.html
├── main.dart.js          (or main.dart.js.gz)
├── flutter_bootstrap.js
├── manifest.json
├── favicon.png
├── assets/
│   └── ...
└── icons/
    └── ...
```

If these files don't exist, the build didn't complete successfully.

