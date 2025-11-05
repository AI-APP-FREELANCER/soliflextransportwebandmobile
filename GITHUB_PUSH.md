# Push Code to GitHub - Quick Guide

## Repository URL
**https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git**

---

## Step-by-Step Commands (Run on Windows)

### Step 1: Navigate to Project Directory

Open **PowerShell** or **Git Bash** and run:

```powershell
cd C:\Users\shyam\Documents\Dev\soliflexweb\new
```

### Step 2: Check Git Status

```powershell
git status
```

### Step 3: Initialize Git (if not already done)

```powershell
git init
```

### Step 4: Add Remote Repository

```powershell
# Check if remote already exists
git remote -v

# If no remote exists, add it:
git remote add origin https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git

# If remote exists but wrong URL, update it:
git remote set-url origin https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git
```

### Step 5: Add All Files

```powershell
git add .
```

### Step 6: Commit Changes

```powershell
git commit -m "Deploy: Soliflex Packaging Transporter with enhanced UI, workflow system, and PM2 configuration"
```

### Step 7: Set Main Branch

```powershell
git branch -M main
```

### Step 8: Push to GitHub

```powershell
# First push (creates main branch)
git push -u origin main

# Or if repository already has content, you might need to pull first:
git pull origin main --allow-unrelated-histories
git push -u origin main
```

---

## Alternative: Using GitHub Desktop

1. Open **GitHub Desktop**
2. Click **File** → **Add Local Repository**
3. Select: `C:\Users\shyam\Documents\Dev\soliflexweb\new`
4. Click **Publish repository** (if first time)
5. Or click **Push origin** if already connected

---

## Verify Push

1. Go to: https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile
2. Check that all files are visible
3. Verify these files exist:
   - `ecosystem.config.js`
   - `deploy.sh`
   - `DEPLOYMENT.md`
   - `README.md`
   - `backend/`
   - `lib/`

---

## Troubleshooting

### If you get "remote origin already exists":

```powershell
# Remove existing remote
git remote remove origin

# Add correct remote
git remote add origin https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git
```

### If you get "refusing to merge unrelated histories":

```powershell
git pull origin main --allow-unrelated-histories
git push -u origin main
```

### If you get authentication error:

```powershell
# Use GitHub Personal Access Token instead of password
# Or use SSH:
git remote set-url origin git@github.com:AI-APP-FREELANCER/soliflextransportwebandmobile.git
```

---

## Next Steps

After pushing to GitHub, follow the **DEPLOYMENT.md** guide to deploy on Ubuntu VM.

