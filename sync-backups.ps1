# Script dong bo cac file backup tu Kubernetes PVC ra thu muc backups tren may Windows

$backupDir = "$PSScriptRoot\backups"
if (!(Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

Write-Host "Dang tim Pod SQL Server va quet cac file backup..." -ForegroundColor Cyan

# 1. Lay ten Pod SQL Server thuc te
$podName = kubectl get pod -l app=sqlserver -o jsonpath='{.items[0].metadata.name}'

if (-not $podName) {
    Write-Host "Khong tim thay Pod SQL Server nao dang chay!" -ForegroundColor Red
    exit 1
}

# 2. Lay danh sach tat ca cac file .bak trong Pod sqlserver
$files = kubectl exec $podName -- /bin/bash -c "ls -1 /var/opt/mssql/backup_auto_*.bak 2>/dev/null"
$fileList = $files -split "`r?`n" | Where-Object { $_ -ne "" }

if (-not $fileList) {
    Write-Host "Khong tim thay file backup nao trong Pod SQL Server!" -ForegroundColor Yellow
    exit 0
}

# 3. Copy tung file ve thu muc backups (dung duong dan tuong doi de tranh loi o dia Windows)
foreach ($remoteFile in $fileList) {
    $fileName = Split-Path $remoteFile -Leaf
    $destination = "backups/$fileName"
    $checkLocal = Join-Path $backupDir $fileName
    
    if (-not (Test-Path $checkLocal)) {
        Write-Host "Dang copy: $fileName -> backups/..." -ForegroundColor Yellow
        kubectl cp "${podName}:${remoteFile}" "$destination"
        if (Test-Path $checkLocal) {
            Write-Host "-> Da dong bo thanh cong: $fileName" -ForegroundColor Green
        }
    } else {
        Write-Host "-> File da co tren may: $fileName (Bo qua)" -ForegroundColor Gray
    }
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "DONG BO HOAN TAT!" -ForegroundColor Green
Write-Host "Hay kiem tra thu muc: $backupDir" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
