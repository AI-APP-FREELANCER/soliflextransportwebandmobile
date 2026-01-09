# Verify Latest Changes on VM

## Quick Verification Commands

Run these commands on your VM to verify the port 5000 changes are present:

### 1. Check ecosystem.config.js

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Check if PORT is set to 5000
grep -n "PORT" ecosystem.config.js
```

**Expected output:**
```
11:        PORT: 5000
```

### 2. Check backend/server.js

```bash
# Check if default port is 5000
grep -n "PORT = process.env.PORT" backend/server.js
```

**Expected output:**
```
12:const PORT = process.env.PORT || 5000;
```

### 3. Check Git Log

```bash
# See recent commits
git log --oneline -10

# Check if your latest commit is there
git log --oneline --all | head -5
```

### 4. Check Current Branch and Remote Status

```bash
# Check current branch
git branch

# Check remote status
git status

# Check if local is behind remote
git fetch origin
git status
```

### 5. Compare with Remote

```bash
# See what commits are on remote but not local
git fetch origin
git log HEAD..origin/main --oneline

# See what commits are local but not on remote
git log origin/main..HEAD --oneline
```

### 6. Check File Content Directly

```bash
# View the actual port in ecosystem.config.js
cat ecosystem.config.js | grep -A 2 "PORT"

# View the actual port in server.js
cat backend/server.js | grep "PORT ="
```

## Expected Results

If changes are present, you should see:

**ecosystem.config.js:**
```javascript
env: {
  NODE_ENV: 'production',
  PORT: 5000
},
```

**backend/server.js:**
```javascript
const PORT = process.env.PORT || 5000;
```

## If Changes Are NOT Present

If the files still show port 3000 or 4000:

### Option 1: Force Pull (if you're sure remote is correct)

```bash
# Fetch latest
git fetch origin

# Reset to match remote (WARNING: This will discard local changes)
git reset --hard origin/main

# Or just pull with force
git pull origin main --force
```

### Option 2: Check if you're on the right branch

```bash
# Check current branch
git branch

# Switch to main if needed
git checkout main

# Pull again
git pull origin main
```

### Option 3: Manual Update (if git pull isn't working)

```bash
# Edit ecosystem.config.js
nano ecosystem.config.js
# Change PORT: 3000 (or 4000) to PORT: 5000

# Edit backend/server.js
nano backend/server.js
# Change const PORT = process.env.PORT || 3000; to const PORT = process.env.PORT || 5000;
```

## Verify After Update

After making changes, verify:

```bash
# Check ecosystem.config.js
grep "PORT" ecosystem.config.js

# Check server.js
grep "PORT =" backend/server.js

# Restart backend
pm2 restart soliflex-backend

# Check logs (should show port 5000)
pm2 logs soliflex-backend --lines 5
```

## Complete Verification Script

Run this complete verification:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

echo "=== Checking ecosystem.config.js ==="
grep -A 1 "PORT" ecosystem.config.js

echo ""
echo "=== Checking backend/server.js ==="
grep "PORT = process.env.PORT" backend/server.js

echo ""
echo "=== Checking Git Status ==="
git status

echo ""
echo "=== Latest Commits ==="
git log --oneline -5

echo ""
echo "=== Checking if behind remote ==="
git fetch origin
git log HEAD..origin/main --oneline

echo ""
echo "=== PM2 Status ==="
pm2 list | grep soliflex-backend
```

This will show you everything you need to verify the changes are present.

