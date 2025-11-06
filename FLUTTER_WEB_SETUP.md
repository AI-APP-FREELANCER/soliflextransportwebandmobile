# Flutter Web Setup - Quick Fix

## Problem
```
This project is not configured for the web.
To configure this project for the web, run flutter create . --platforms web
```

## Solution

Run these commands **on your Ubuntu VM**:

### Step 1: Enable Web Support
```bash
# Make sure you're in the project root
cd ~/transport/transportwebandmobile/soliflexweb

# Enable web platform support
flutter create . --platforms web
```

### Step 2: Verify Web Support
```bash
# Check if web directory was created
ls -la web/

# You should see:
# - index.html
# - manifest.json
# - icons/ (directory)
```

### Step 3: Build Flutter Web
```bash
# Get Flutter dependencies
flutter pub get

# Build Flutter web (release mode)
flutter build web --release
```

### Step 4: Verify Build Output
```bash
# Check if build/web directory exists
ls -la build/web/

# You should see:
# - index.html
# - main.dart.js
# - assets/
# - other files
```

---

## Complete Command Sequence

If you want to do it all at once:

```bash
cd ~/transport/transportwebandmobile/soliflexweb && \
flutter create . --platforms web && \
flutter pub get && \
flutter build web --release && \
ls -la build/web/
```

---

## After Building, Continue with PM2 Deployment

Once the build is successful, continue with starting the apps:

```bash
# Stop previous apps (if running)
pm2 stop all
pm2 delete all

# Create logs directory
mkdir -p logs

# Start apps with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Copy and run the generated command with sudo
```

---

## Troubleshooting

### If `flutter create` fails with "overwrite" error:
```bash
# Use --overwrite flag
flutter create . --platforms web --overwrite
```

### If web directory already exists:
```bash
# Just build directly
flutter pub get
flutter build web --release
```

### If you get permission errors:
```bash
# Make sure you're in the correct directory
pwd
# Should show: /home/soliflexuser/transport/transportwebandmobile/soliflexweb

# Check if you have write permissions
ls -la
```

