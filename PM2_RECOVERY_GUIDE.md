# PM2 Recovery Guide - Restore All Applications

## Quick Recovery Commands

### Step 1: Check Current PM2 Status

```bash
# View all PM2 processes (running and stopped)
pm2 list

# View detailed information
pm2 show all

# Check PM2 daemon status
pm2 ping
```

### Step 2: Check PM2 Saved Configuration

```bash
# View saved PM2 startup configuration
pm2 startup

# Check saved process list
cat ~/.pm2/dump.pm2

# View PM2 saved ecosystem files
ls -la ~/.pm2/
```

### Step 3: Restore All Saved PM2 Processes

```bash
# Method 1: Restore from saved dump (if PM2 was saved before)
pm2 resurrect

# Method 2: If you have ecosystem.config.js files, start them
# For Soliflex Transport app:
cd ~/transport/transportwebandmobile/soliflexweb
pm2 start ecosystem.config.js
pm2 save

# For other application (if you know the path):
# cd /path/to/other/app
# pm2 start ecosystem.config.js
# pm2 save
```

### Step 4: Find All PM2 Ecosystem Files on VM

```bash
# Search for all ecosystem.config.js files
find ~ -name "ecosystem.config.js" 2>/dev/null

# Search for all PM2 config files
find ~ -name "*.config.js" -path "*/ecosystem*" 2>/dev/null

# Check common application directories
ls -la ~/transport/
ls -la ~/
```

### Step 5: Manual Process Recovery

If you know the application names or scripts:

```bash
# Example: If you had an app called "sol-emp-backend"
# Check if it exists in PM2
pm2 list | grep sol-emp

# If it shows as stopped, restart it
pm2 restart sol-emp-backend

# If it doesn't exist, you need to start it manually
# First, find where the app is located
find ~ -name "server.js" -o -name "app.js" -o -name "index.js" 2>/dev/null | grep -v node_modules

# Then start it (example):
# cd /path/to/app
# pm2 start server.js --name "app-name"
# pm2 save
```

### Step 6: Check PM2 Logs for Clues

```bash
# View all PM2 logs
pm2 logs --lines 50

# Check PM2 error logs
pm2 logs --err --lines 50

# View logs for specific app (if you know the name)
pm2 logs sol-emp-backend --lines 50
```

### Step 7: Check Running Ports to Identify Apps

```bash
# Check what's running on common ports
sudo netstat -tulpn | grep LISTEN

# Or using ss command
sudo ss -tulpn | grep LISTEN

# Check specific ports
sudo lsof -i :3000
sudo lsof -i :4000
sudo lsof -i :5000
sudo lsof -i :8081
```

### Step 8: Complete PM2 Recovery Process

```bash
# 1. Stop all processes (clean slate)
pm2 stop all

# 2. Delete all processes
pm2 delete all

# 3. Clear PM2 logs
pm2 flush

# 4. Restore from saved configuration
pm2 resurrect

# 5. If resurrect doesn't work, manually start each app:

# For Soliflex Transport:
cd ~/transport/transportwebandmobile/soliflexweb
pm2 start ecosystem.config.js

# For other application (adjust path and name):
# cd /path/to/other/app
# pm2 start ecosystem.config.js --name "other-app-name"
# OR if it has a different config:
# pm2 start ecosystem.config.js

# 6. Save all configurations
pm2 save

# 7. Verify all processes are running
pm2 list

# 8. Check logs
pm2 logs --lines 20
```

### Step 9: Verify All Applications Are Running

```bash
# List all processes
pm2 list

# Check status of each
pm2 status

# Monitor all processes
pm2 monit

# Test each application (adjust ports as needed)
curl http://localhost:5000/health  # Soliflex backend
curl http://localhost:8081          # Soliflex frontend
# curl http://localhost:XXXX        # Other app (replace XXXX with its port)
```

## Common PM2 Commands Reference

```bash
# List all processes
pm2 list

# Start a process
pm2 start <app-name>
pm2 start ecosystem.config.js
pm2 start server.js --name "my-app"

# Stop a process
pm2 stop <app-name>
pm2 stop all

# Restart a process
pm2 restart <app-name>
pm2 restart all

# Delete a process
pm2 delete <app-name>
pm2 delete all

# View logs
pm2 logs
pm2 logs <app-name>
pm2 logs <app-name> --lines 50

# Monitor resources
pm2 monit

# Save current process list
pm2 save

# Restore saved processes
pm2 resurrect

# Reload (zero-downtime restart)
pm2 reload <app-name>
pm2 reload all

# Show process details
pm2 show <app-name>

# Flush logs
pm2 flush
```

## Finding Your Other Application

If you're not sure where your other application is:

```bash
# Search for common Node.js app files
find ~ -type f -name "package.json" 2>/dev/null | grep -v node_modules

# Check each package.json to find the app
# Then look for ecosystem.config.js or server files in those directories

# Search for PM2-related files
find ~ -name "ecosystem*.js" 2>/dev/null
find ~ -name "pm2*.json" 2>/dev/null

# Check PM2 process list for app names
pm2 list

# Check systemd services (if any apps are registered)
systemctl list-units | grep pm2
```

## Troubleshooting

### If PM2 resurrect doesn't work:

```bash
# Check if dump file exists
ls -la ~/.pm2/dump.pm2

# If it exists, you can manually inspect it
cat ~/.pm2/dump.pm2 | less

# Or try to restore specific processes from the dump
pm2 resurrect
```

### If you can't find the other app:

```bash
# Check PM2 logs for startup messages
pm2 logs --lines 100 | grep -i "start\|running\|port"

# Check system logs
journalctl -u pm2-* --no-pager | tail -50

# Check for any running Node processes
ps aux | grep node

# Check for any PM2 processes
ps aux | grep pm2
```

## Quick Recovery Script

Save this as `restore-pm2.sh` and run it:

```bash
#!/bin/bash

echo "=== PM2 Recovery Script ==="

# 1. Check current status
echo "Current PM2 status:"
pm2 list

# 2. Try to restore
echo "Attempting to restore saved processes..."
pm2 resurrect

# 3. If you know the paths, start them manually
echo "Starting known applications..."

# Soliflex Transport
if [ -d ~/transport/transportwebandmobile/soliflexweb ]; then
    echo "Starting Soliflex Transport..."
    cd ~/transport/transportwebandmobile/soliflexweb
    pm2 start ecosystem.config.js 2>/dev/null || echo "Already running or error"
fi

# Add other applications here
# if [ -d /path/to/other/app ]; then
#     echo "Starting Other App..."
#     cd /path/to/other/app
#     pm2 start ecosystem.config.js 2>/dev/null || echo "Already running or error"
# fi

# 4. Save configuration
pm2 save

# 5. Show final status
echo "Final PM2 status:"
pm2 list

echo "=== Recovery Complete ==="
```

Make it executable and run:
```bash
chmod +x restore-pm2.sh
./restore-pm2.sh
```

