# GitHub Authentication Setup

GitHub no longer supports password authentication. You need to use either:
1. **Personal Access Token (PAT)** - Easier, quick setup
2. **SSH Keys** - More secure, recommended for long-term use

---

## Option 1: Personal Access Token (PAT) - Quick Setup

### Step 1: Create Personal Access Token on GitHub

1. Go to GitHub.com and sign in
2. Click your profile picture (top right) → **Settings**
3. Scroll down to **Developer settings** (left sidebar)
4. Click **Personal access tokens** → **Tokens (classic)**
5. Click **Generate new token** → **Generate new token (classic)**
6. Give it a name: `Soliflex VM Access`
7. Select expiration (e.g., 90 days or No expiration)
8. Check these scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (if you use GitHub Actions)
9. Click **Generate token**
10. **COPY THE TOKEN IMMEDIATELY** - you won't see it again!

### Step 2: Use Token on Ubuntu VM

**Method A: Use token as password when pushing**

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# When prompted for password, paste your Personal Access Token
git push origin main
# Username: shyamkumar0707
# Password: <paste your token here>
```

**Method B: Store token in Git credential helper (recommended)**

```bash
# Configure Git to store credentials
git config --global credential.helper store

# Now push (will ask for username and password once)
git push origin main
# Username: shyamkumar0707
# Password: <paste your token here>

# Git will save it for future use
```

**Method C: Update remote URL with token (less secure)**

```bash
# Replace YOUR_TOKEN with your actual token
git remote set-url origin https://YOUR_TOKEN@github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git

# Now push without authentication prompt
git push origin main
```

---

## Option 2: SSH Keys - More Secure (Recommended)

### Step 1: Generate SSH Key on Ubuntu VM

```bash
# Generate SSH key (use your GitHub email)
ssh-keygen -t ed25519 -C "shyamkumar0707@users.noreply.github.com"

# Press Enter to accept default file location (~/.ssh/id_ed25519)
# Press Enter twice for no passphrase (or set one if you want)

# Start SSH agent
eval "$(ssh-agent -s)"

# Add SSH key to agent
ssh-add ~/.ssh/id_ed25519
```

### Step 2: Copy Public Key

```bash
# Display your public key
cat ~/.ssh/id_ed25519.pub

# Copy the entire output (starts with ssh-ed25519...)
```

### Step 3: Add SSH Key to GitHub

1. Go to GitHub.com → **Settings** → **SSH and GPG keys**
2. Click **New SSH key**
3. Title: `Soliflex Ubuntu VM`
4. Key: Paste your public key (from Step 2)
5. Click **Add SSH key**

### Step 4: Update Git Remote to Use SSH

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Change remote URL from HTTPS to SSH
git remote set-url origin git@github.com:AI-APP-FREELANCER/soliflextransportwebandmobile.git

# Test SSH connection
ssh -T git@github.com
# Should say: Hi AI-APP-FREELANCER! You've successfully authenticated...

# Now push (no authentication needed)
git push origin main
```

---

## Quick Fix: Use PAT Right Now

If you need to push immediately, use Option 1 Method A:

```bash
cd ~/transport/transportwebandmobile/soliflexweb

# Add and commit the fix
git add lib/theme/app_theme.dart
git commit -m "Fix: Change CardTheme to CardThemeData for Flutter compatibility"

# Push (use your Personal Access Token as password)
git push origin main
# Username: shyamkumar0707
# Password: <paste your GitHub Personal Access Token>
```

---

## Troubleshooting

### If you forgot your token:
- Generate a new one (old ones can't be retrieved)
- Revoke old tokens in GitHub Settings → Developer settings → Personal access tokens

### If SSH connection fails:
```bash
# Test SSH connection
ssh -T git@github.com

# If it says "Permission denied", check:
# 1. Did you add the public key to GitHub?
# 2. Is the SSH agent running?
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### If you want to switch between HTTPS and SSH:
```bash
# Check current remote URL
git remote -v

# Switch to SSH
git remote set-url origin git@github.com:AI-APP-FREELANCER/soliflextransportwebandmobile.git

# Switch back to HTTPS
git remote set-url origin https://github.com/AI-APP-FREELANCER/soliflextransportwebandmobile.git
```

---

## Recommendation

For quick setup: **Use Personal Access Token (Option 1, Method B)**  
For long-term security: **Use SSH Keys (Option 2)**

