# Complete Flutter Web Rebuild

## Problem
Build is incomplete - missing `main.dart.js`, `manifest.json`, and other required files.

## Solution: Complete Rebuild

### Step 1: Clean Everything

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Clean Flutter build
flutter clean

# Remove build directory completely
rm -rf build/

# Verify it's gone
ls -la build/ 2>/dev/null || echo "Build directory cleaned"
```

### Step 2: Check Flutter Setup

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check Flutter version
flutter --version

# Check Flutter doctor
flutter doctor -v

# Make sure web is enabled
flutter config --enable-web
```

### Step 3: Ensure Web Directory Exists

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if web directory exists
if [ ! -d "web" ]; then
    echo "Creating web directory..."
    flutter create . --platforms web
fi

# Verify web directory
ls -la web/
# Should see: index.html, manifest.json, icons/
```

### Step 4: Get Dependencies

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Get Flutter dependencies
flutter pub get

# Check for errors
if [ $? -eq 0 ]; then
    echo "✓ Dependencies installed successfully"
else
    echo "✗ Error installing dependencies"
    exit 1
fi
```

### Step 5: Build Flutter Web (Watch for Errors)

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Build with verbose output to see any errors
flutter build web --release --pwa-strategy=none --verbose 2>&1 | tee build.log

# Check the log for errors
echo ""
echo "=== Checking for errors ==="
grep -i "error" build.log | head -20
grep -i "failed" build.log | head -20
```

### Step 6: Verify Complete Build

```bash
cd ~/transport/transportwebandmobile/soliflexweb

echo "=== Build Verification ==="

# Check if build/web exists
if [ ! -d "build/web" ]; then
    echo "✗ BUILD FAILED - build/web does not exist"
    exit 1
fi

# Check for main.dart.js
if [ -f "build/web/main.dart.js" ]; then
    echo "✓ main.dart.js exists ($(du -h build/web/main.dart.js | cut -f1))"
else
    echo "✗ main.dart.js NOT FOUND"
    echo "Checking for alternative files:"
    find build/web -name "*main*" -type f
fi

# Check for manifest.json
if [ -f "build/web/manifest.json" ]; then
    echo "✓ manifest.json exists"
else
    echo "✗ manifest.json NOT FOUND"
fi

# Check for assets
if [ -d "build/web/assets" ]; then
    echo "✓ assets/ directory exists"
    ls -lh build/web/assets/ | head -5
else
    echo "✗ assets/ directory NOT FOUND"
fi

# List all files
echo ""
echo "All files in build/web:"
ls -lh build/web/
```

---

## Complete Rebuild Script

Run this complete sequence:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# 1. Clean everything
echo "Step 1: Cleaning..."
flutter clean
rm -rf build/

# 2. Ensure web platform is configured
echo "Step 2: Configuring web platform..."
if [ ! -d "web" ]; then
    flutter create . --platforms web
fi
flutter config --enable-web

# 3. Get dependencies
echo "Step 3: Getting dependencies..."
flutter pub get

# 4. Build Flutter web
echo "Step 4: Building Flutter web (this may take a few minutes)..."
flutter build web --release --pwa-strategy=none

# 5. Verify build
echo ""
echo "=== Build Verification ==="
if [ -d "build/web" ]; then
    echo "✓ build/web exists"
    
    # Check for main.dart.js
    if [ -f "build/web/main.dart.js" ]; then
        echo "✓ main.dart.js exists"
        ls -lh build/web/main.dart.js
    else
        echo "✗ main.dart.js NOT FOUND"
        echo "Files in build/web:"
        ls -lh build/web/
        echo ""
        echo "This indicates the build failed. Check the error messages above."
        exit 1
    fi
    
    # Check for manifest.json
    if [ -f "build/web/manifest.json" ]; then
        echo "✓ manifest.json exists"
    else
        echo "✗ manifest.json NOT FOUND"
    fi
    
    # List all files
    echo ""
    echo "All files in build/web:"
    ls -lh build/web/
else
    echo "✗ BUILD FAILED - build/web does not exist"
    exit 1
fi
```

---

## If Build Still Fails

### Check for Compilation Errors

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Try building with verbose output
flutter build web --release --pwa-strategy=none --verbose 2>&1 | tee build.log

# Look for specific errors
cat build.log | grep -i "error" | head -30
cat build.log | grep -i "failed" | head -30
cat build.log | grep -i "exception" | head -30
```

### Check Flutter Version Compatibility

```bash
# Check Flutter version
flutter --version

# Check if there are any known issues
flutter doctor -v

# Try updating Flutter
flutter upgrade
```

### Check for Dart Compilation Errors

The build might be failing during Dart compilation. Look for errors like:
- Type errors
- Import errors
- Missing dependencies

If you see compilation errors, share them and we can fix the code.

---

## After Successful Build

Once `main.dart.js` exists:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Restart PM2
pm2 stop soliflex-frontend
pm2 delete soliflex-frontend
pm2 start ecosystem.config.js
pm2 save

# Test locally
curl http://localhost:8081/main.dart.js | head -5
curl http://localhost:8081/manifest.json
```

