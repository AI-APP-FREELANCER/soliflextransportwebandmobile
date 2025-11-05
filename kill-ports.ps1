# PowerShell script to kill processes on ports 3000 and 8081

Write-Host "Finding processes on ports 3000 and 8081..." -ForegroundColor Yellow

# Find processes on port 3000
$port3000 = Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if ($port3000) {
    Write-Host "Found processes on port 3000: $port3000" -ForegroundColor Cyan
    $port3000 | ForEach-Object {
        $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Killing process $($proc.ProcessName) (PID: $_) on port 3000" -ForegroundColor Red
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "No processes found on port 3000" -ForegroundColor Green
}

# Find processes on port 8081
$port8081 = Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if ($port8081) {
    Write-Host "Found processes on port 8081: $port8081" -ForegroundColor Cyan
    $port8081 | ForEach-Object {
        $proc = Get-Process -Id $_ -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Killing process $($proc.ProcessName) (PID: $_) on port 8081" -ForegroundColor Red
            Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "No processes found on port 8081" -ForegroundColor Green
}

# Also kill Flutter and Node processes directly
Write-Host "`nKilling all Flutter and Node processes..." -ForegroundColor Yellow

Get-Process | Where-Object {$_.ProcessName -match "dart|flutter"} | ForEach-Object {
    Write-Host "Killing Flutter process: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Red
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Get-Process | Where-Object {$_.ProcessName -eq "node"} | ForEach-Object {
    Write-Host "Killing Node process: $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Red
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "`nDone! All processes killed." -ForegroundColor Green

