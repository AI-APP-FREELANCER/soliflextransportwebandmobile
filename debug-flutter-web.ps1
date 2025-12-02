# PowerShell script to diagnose and fix Flutter Web Debug Connection Issues
# This script addresses SocketException errors when running flutter run -d chrome

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Flutter Web Debug Connection Diagnostics" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check for running Flutter/Dart processes
Write-Host "[P1] Checking for existing Flutter/Dart processes..." -ForegroundColor Yellow
$flutterProcesses = Get-Process | Where-Object {$_.ProcessName -match "dart|flutter|chrome"} | Select-Object ProcessName, Id, Path
if ($flutterProcesses) {
    Write-Host "Found running processes:" -ForegroundColor Yellow
    $flutterProcesses | Format-Table -AutoSize
    $kill = Read-Host "Kill these processes? (y/n)"
    if ($kill -eq 'y') {
        Get-Process | Where-Object {$_.ProcessName -match "dart|flutter"} | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "Processes killed." -ForegroundColor Green
    }
} else {
    Write-Host "No conflicting processes found." -ForegroundColor Green
}
Write-Host ""

# Step 2: Check port availability
Write-Host "[P2] Checking port availability (60000-61000 range)..." -ForegroundColor Yellow
$portsInUse = @()
for ($port = 60000; $port -le 61000; $port++) {
    $connection = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($connection) {
        $portsInUse += $port
    }
}
if ($portsInUse.Count -gt 0) {
    Write-Host "Ports in use: $($portsInUse -join ', ')" -ForegroundColor Yellow
} else {
    Write-Host "No conflicts in debug port range." -ForegroundColor Green
}
Write-Host ""

# Step 3: Check Windows Firewall status
Write-Host "[P3] Checking Windows Firewall status..." -ForegroundColor Yellow
$firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled
foreach ($profile in $firewallProfiles) {
    if ($profile.Enabled) {
        Write-Host "Firewall Profile: $($profile.Name) - ENABLED" -ForegroundColor Yellow
        Write-Host "  Consider adding an exception for Flutter/Dart debug ports" -ForegroundColor Yellow
    } else {
        Write-Host "Firewall Profile: $($profile.Name) - DISABLED" -ForegroundColor Green
    }
}
Write-Host ""

# Step 4: Check for VPN/Proxy
Write-Host "[P4] Checking for VPN/Proxy interference..." -ForegroundColor Yellow
$vpnAdapters = Get-NetAdapter | Where-Object {$_.InterfaceDescription -match "VPN|TAP|TUN|OpenVPN|WireGuard"} | Select-Object Name, Status
if ($vpnAdapters) {
    Write-Host "VPN adapters found:" -ForegroundColor Yellow
    $vpnAdapters | Format-Table -AutoSize
    Write-Host "  WARNING: VPN may interfere with localhost connections" -ForegroundColor Red
    Write-Host "  Recommendation: Temporarily disable VPN for debugging" -ForegroundColor Yellow
} else {
    Write-Host "No VPN adapters detected." -ForegroundColor Green
}
Write-Host ""

# Step 5: Check Flutter configuration
Write-Host "[P5] Checking Flutter configuration..." -ForegroundColor Yellow
$flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if ($flutterPath) {
    Write-Host "Flutter found at: $flutterPath" -ForegroundColor Green
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
    Write-Host $flutterVersion
} else {
    Write-Host "Flutter not found in PATH!" -ForegroundColor Red
}
Write-Host ""

# Step 6: Clear Flutter cache
Write-Host "[P6] Flutter cache cleanup options..." -ForegroundColor Yellow
$clearCache = Read-Host "Clear Flutter cache? This may help resolve connection issues (y/n)"
if ($clearCache -eq 'y') {
    Write-Host "Clearing Flutter cache..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
    Write-Host "Cache cleared." -ForegroundColor Green
}
Write-Host ""

# Step 7: Create firewall rule (optional)
Write-Host "[P7] Windows Firewall Rule Creation..." -ForegroundColor Yellow
$createRule = Read-Host "Create Windows Firewall rule for Flutter debug ports (60000-61000)? (y/n)"
if ($createRule -eq 'y') {
    try {
        $ruleName = "Flutter Web Debug Service"
        Write-Host "Creating firewall rule: $ruleName" -ForegroundColor Yellow
        
        # Remove existing rule if present
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        # Create new rule for inbound connections
        New-NetFirewallRule -DisplayName $ruleName `
            -Direction Inbound `
            -LocalPort 60000-61000 `
            -Protocol TCP `
            -Action Allow `
            -Description "Allow Flutter/Dart Web Debug Service connections on localhost" | Out-Null
        
        Write-Host "Firewall rule created successfully!" -ForegroundColor Green
    } catch {
        Write-Host "Failed to create firewall rule. You may need to run as Administrator." -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
    }
}
Write-Host ""

# Step 8: Test localhost connectivity
Write-Host "[P8] Testing localhost connectivity..." -ForegroundColor Yellow
try {
    $testConnection = Test-NetConnection -ComputerName localhost -Port 3000 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($testConnection) {
        Write-Host "localhost:3000 is reachable (backend check)" -ForegroundColor Green
    } else {
        Write-Host "localhost:3000 is not reachable" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not test localhost connectivity" -ForegroundColor Yellow
}
Write-Host ""

# Step 9: Recommended launch command
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Recommended Launch Commands" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Option 1: Standard debug mode" -ForegroundColor Yellow
Write-Host "  flutter run -d chrome --web-port=8081" -ForegroundColor White
Write-Host ""
Write-Host "Option 2: Release mode (no debug, faster)" -ForegroundColor Yellow
Write-Host "  flutter run -d chrome --web-port=8081 --release" -ForegroundColor White
Write-Host ""
Write-Host "Option 3: Profile mode (balanced)" -ForegroundColor Yellow
Write-Host "  flutter run -d chrome --web-port=8081 --profile" -ForegroundColor White
Write-Host ""
Write-Host "Option 4: With verbose logging" -ForegroundColor Yellow
Write-Host "  flutter run -d chrome --web-port=8081 --verbose" -ForegroundColor White
Write-Host ""

# Step 10: Alternative Chrome launch
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Alternative: Launch Chrome Manually" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If debug connection still fails, try:" -ForegroundColor Yellow
Write-Host "1. Close all Chrome instances" -ForegroundColor White
Write-Host "2. Launch Chrome with remote debugging:" -ForegroundColor White
Write-Host "   chrome.exe --remote-debugging-port=9222 --user-data-dir=`"C:\temp\chrome-debug`"" -ForegroundColor Cyan
Write-Host "3. Then run: flutter run -d chrome --web-port=8081" -ForegroundColor White
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Diagnostics Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. If firewall is enabled, ensure Flutter debug ports are allowed" -ForegroundColor White
Write-Host "2. Temporarily disable VPN if active" -ForegroundColor White
Write-Host "3. Try running Flutter with --release flag to bypass debug service" -ForegroundColor White
Write-Host "4. Check Windows Event Viewer for blocked connection attempts" -ForegroundColor White
Write-Host ""

