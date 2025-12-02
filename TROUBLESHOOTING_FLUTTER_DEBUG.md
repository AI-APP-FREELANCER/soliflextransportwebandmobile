# Flutter Web Debug Connection Troubleshooting Guide

## Problem
SocketException: The remote computer refused the network connection (errno = 1225) when running `flutter run -d chrome`.

## Root Cause
The Dart Web Debug Service (DWDS) cannot establish a WebSocket connection to Chrome on localhost high-numbered ports (typically 60000-61000 range).

## Diagnostic Steps

### P1: Firewall Check (Priority 1)

**Windows Defender Firewall:**
1. Open Windows Security → Firewall & network protection
2. Click "Advanced settings"
3. Check Inbound Rules for any blocking rules
4. Temporarily disable firewall to test:
   ```powershell
   # Run PowerShell as Administrator
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
   ```
5. Test Flutter: `flutter run -d chrome --web-port=8081`
6. If it works, re-enable firewall and create an exception:
   ```powershell
   # Run PowerShell as Administrator
   New-NetFirewallRule -DisplayName "Flutter Web Debug Service" `
       -Direction Inbound -LocalPort 60000-61000 -Protocol TCP -Action Allow
   ```

**Third-Party Firewalls (McAfee, Norton, etc.):**
- Temporarily disable to test
- Add exception for Flutter/Dart processes
- Allow localhost connections on ports 60000-61000

### P2: VPN/Proxy Check (Priority 2)

**If using VPN:**
1. Disconnect VPN temporarily
2. Test Flutter debug connection
3. If it works, VPN is interfering
4. Solutions:
   - Add localhost/127.0.0.1 to VPN bypass list
   - Use split tunneling to exclude localhost
   - Disable VPN during development

**If using Proxy:**
1. Check proxy settings: `netsh winhttp show proxy`
2. If proxy is set, try bypassing localhost:
   ```powershell
   netsh winhttp set proxy proxy-server="your-proxy" bypass-list="localhost;127.0.0.1;*.local"
   ```

### P3: Port Availability (Priority 3)

**Check if ports are in use:**
```powershell
# Check specific port (replace 60710 with your port)
netstat -ano | findstr :60710

# Check entire debug port range
netstat -ano | findstr "60000 60001 60002 60003 60004 60005 60006 60007 60008 60009 60100"
```

**Kill process using port:**
```powershell
# Find PID from netstat output, then:
taskkill /PID <PID> /F
```

### P4: Chrome Debug Configuration (Priority 4)

**Option A: Clean Chrome Launch**
1. Close all Chrome instances
2. Clear Flutter cache:
   ```powershell
   flutter clean
   flutter pub get
   ```
3. Launch Chrome manually with debug port:
   ```powershell
   # Create temp directory
   mkdir C:\temp\chrome-debug
   
   # Launch Chrome with remote debugging
   & "C:\Program Files\Google\Chrome\Application\chrome.exe" `
       --remote-debugging-port=9222 `
       --user-data-dir="C:\temp\chrome-debug"
   ```
4. In another terminal, run:
   ```powershell
   flutter run -d chrome --web-port=8081
   ```

**Option B: Use Release Mode (Bypass Debug Service)**
```powershell
flutter run -d chrome --web-port=8081 --release
```
This bypasses the debug service entirely but loses debugging capabilities.

**Option C: Use Profile Mode**
```powershell
flutter run -d chrome --web-port=8081 --profile
```

### P5: Flutter/Dart Process Cleanup

**Kill all Flutter/Dart processes:**
```powershell
Get-Process | Where-Object {$_.ProcessName -match "dart|flutter"} | Stop-Process -Force
```

**Kill Chrome processes:**
```powershell
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
```

### P6: Flutter Cache and Configuration

**Clear Flutter cache:**
```powershell
flutter clean
flutter pub get
```

**Check Flutter doctor:**
```powershell
flutter doctor -v
```

**Update Flutter:**
```powershell
flutter upgrade
```

### P7: Alternative Debugging Methods

**Use VS Code/Android Studio:**
- Launch debugger from IDE instead of command line
- IDEs often handle port conflicts better

**Use Chrome DevTools directly:**
1. Build web app: `flutter build web`
2. Serve with http-server: `npx http-server build/web -p 8081`
3. Open Chrome DevTools manually (F12)

## Quick Fix Script

Run the diagnostic script:
```powershell
.\debug-flutter-web.ps1
```

This script will:
- Check for conflicting processes
- Verify port availability
- Check firewall status
- Detect VPN interference
- Offer to create firewall rules
- Provide recommended launch commands

## Expected Outcome

After applying fixes:
- `flutter run -d chrome --web-port=8081` should connect successfully
- You should see: "Waiting for connection from debug service on Chrome..."
- Application should load in Chrome with debug capabilities

## If All Else Fails

1. **Use Release Mode:**
   ```powershell
   flutter run -d chrome --web-port=8081 --release
   ```

2. **Build and Serve Manually:**
   ```powershell
   flutter build web
   npx http-server build/web -p 8081
   ```

3. **Check Windows Event Viewer:**
   - Open Event Viewer → Windows Logs → Security
   - Look for blocked connection attempts
   - Note the port numbers and processes

4. **Contact IT/Network Admin:**
   - If on corporate network, request localhost exception
   - Request firewall rule for development ports

## Prevention

1. Add firewall exception permanently
2. Configure VPN to bypass localhost
3. Use consistent port numbers
4. Keep Flutter and Chrome updated

