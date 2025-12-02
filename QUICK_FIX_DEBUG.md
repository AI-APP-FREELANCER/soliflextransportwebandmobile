# Quick Fix for Flutter Web Debug Connection Error

## Immediate Solution (Try These in Order)

### 1. Run Diagnostic Script
```powershell
.\debug-flutter-web.ps1
```
This will automatically check and fix common issues.

### 2. Quick Firewall Fix (Run as Administrator)
```powershell
New-NetFirewallRule -DisplayName "Flutter Web Debug Service" `
    -Direction Inbound -LocalPort 60000-61000 -Protocol TCP -Action Allow
```

### 3. Use Release Mode (Bypasses Debug Service)
```powershell
flutter run -d chrome --web-port=8081 --release
```

### 4. Clean and Retry
```powershell
# Kill all Flutter processes
Get-Process | Where-Object {$_.ProcessName -match "dart|flutter"} | Stop-Process -Force

# Clean Flutter cache
flutter clean
flutter pub get

# Try again
flutter run -d chrome --web-port=8081
```

## Most Common Causes

1. **Windows Firewall** blocking localhost ports 60000-61000
2. **VPN** interfering with localhost connections
3. **Port conflicts** from previous Flutter sessions
4. **Chrome** not accepting debug connections

## If Nothing Works

Use release mode for development (no debugging, but app works):
```powershell
flutter run -d chrome --web-port=8081 --release
```

Or build and serve manually:
```powershell
flutter build web
npx http-server build/web -p 8081
```

