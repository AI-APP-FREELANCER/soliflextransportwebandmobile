# PowerShell script to start both backend and frontend

Write-Host "Killing existing processes..." -ForegroundColor Yellow

# Kill processes on ports 3000 and 8081
Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }

# Kill Flutter and Node processes
Get-Process | Where-Object {$_.ProcessName -match "dart|flutter"} | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process | Where-Object {$_.ProcessName -eq "node"} | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

Write-Host "`nStarting Backend on port 3000..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot\backend'; npm start"

Start-Sleep -Seconds 3

Write-Host "Starting Flutter Frontend on port 8081..." -ForegroundColor Green
Write-Host "Note: If you encounter SocketException errors, try:" -ForegroundColor Yellow
Write-Host "  1. Run .\debug-flutter-web.ps1 for diagnostics" -ForegroundColor Yellow
Write-Host "  2. Use --release flag: flutter run -d chrome --web-port=8081 --release" -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$PSScriptRoot'; flutter run -d chrome --web-port=8081"

Write-Host "`nDone! Backend: http://localhost:3000" -ForegroundColor Cyan
Write-Host "Frontend: http://localhost:8081" -ForegroundColor Cyan

