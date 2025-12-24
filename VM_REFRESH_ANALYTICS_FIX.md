# Refresh VM After Analytics Dashboard Fix

## Changes Made
- Fixed analytics dashboard to refresh automatically
- Added status normalization for accurate counting
- Added refresh button and automatic refresh on navigation

## Steps to Refresh on VM

### Step 1: Pull Latest Code

```bash
cd ~/transport/transportwebandmobile/soliflexweb
git pull origin main
```

### Step 2: Get Flutter Dependencies

```bash
flutter pub get
```

### Step 3: Rebuild Flutter Web App

Since we changed frontend code (home_screen.dart and main.dart), you need to rebuild:

```bash
flutter build web --release --no-tree-shake-icons
```

### Step 4: Restart PM2 Frontend

```bash
# Restart only the frontend (backend doesn't need restart for this change)
pm2 restart soliflex-frontend

# Or restart both if you want to be safe
pm2 restart all

# Save PM2 configuration
pm2 save
```

### Step 5: Verify

```bash
# Check PM2 status
pm2 list

# Check frontend logs
pm2 logs soliflex-frontend --lines 20
```

## Quick One-Liner (All Steps)

```bash
cd ~/transport/transportwebandmobile/soliflexweb && \
git pull origin main && \
flutter pub get && \
flutter build web --release --no-tree-shake-icons && \
pm2 restart soliflex-frontend && \
pm2 save
```

## What Changed

**Frontend Files:**
- `lib/screens/home_screen.dart` - Added refresh functionality
- `lib/main.dart` - Added route observer

**No Backend Changes** - So backend doesn't need restart, but restarting both is fine.

## Expected Results

After refresh:
- Analytics dashboard will automatically refresh when you navigate back to home
- Status counts will be accurate (case-insensitive matching)
- Refresh button will appear in the app bar
- Counts will update when orders are created/updated

## Troubleshooting

### If build fails:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build web --release --no-tree-shake-icons
```

### If frontend doesn't update:
```bash
# Stop and restart frontend
pm2 stop soliflex-frontend
pm2 delete soliflex-frontend
pm2 start ecosystem.config.js
pm2 save
```

### Check if new code is there:
```bash
# Verify the refresh button code is present
grep -n "Refresh button" lib/screens/home_screen.dart
# Should show the IconButton with refresh icon
```

