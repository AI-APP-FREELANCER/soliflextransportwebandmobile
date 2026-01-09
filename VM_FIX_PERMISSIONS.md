# Fix Flutter Permission Error on VM

## Problem
```
Cannot open file, path = '.dart_tool/package_config.json' (OS Error: Permission denied, errno = 13)
```

This happens when `.dart_tool` directory has incorrect permissions.

## Solution

### Option 1: Fix Permissions (Recommended)

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Remove .dart_tool directory (Flutter will recreate it)
rm -rf .dart_tool

# Also clean build directory if needed
flutter clean

# Now get dependencies
flutter pub get
```

### Option 2: Fix Ownership

If Option 1 doesn't work, fix ownership:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Fix ownership of all files
sudo chown -R $USER:$USER .

# Remove .dart_tool
rm -rf .dart_tool

# Clean and get dependencies
flutter clean
flutter pub get
```

### Option 3: Use sudo (Not Recommended, but works)

```bash
cd ~/transport/transportwebandmobile/soliflexweb
sudo flutter pub get
```

But then you'll need to fix ownership:
```bash
sudo chown -R $USER:$USER .
```

## Complete Refresh After Fixing Permissions

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Fix permissions
rm -rf .dart_tool
flutter clean

# Get dependencies
flutter pub get

# Build
flutter build web --release --no-tree-shake-icons

# Restart frontend
pm2 restart soliflex-frontend
pm2 save
```

## Verify

After fixing, verify:
```bash
# Check if .dart_tool was created
ls -la .dart_tool

# Should show files owned by your user
```

