# Script tu dong backup database SQL Server cho Docker Compose
# Duoc viet boi Antigravity

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFileName = "backup_auto_${timestamp}.bak"
$backupDir = "$PSScriptRoot\backups"

# Tim container SQL Server dang chay
$containerId = docker ps --filter "ancestor=mcr.microsoft.com/mssql/server:2022-latest" --format "{{.ID}}"

if (-not $containerId) {
    Write-Host "Khong tim thay container SQL Server dang chay! Vui long bat docker compose truoc." -ForegroundColor Red
    exit 1
}

Write-Host "Dang thuc hien backup tu container SQL Server ($containerId)..." -ForegroundColor Cyan

# 1. Chay lenh backup ben trong container
docker exec $containerId /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Ctt@1234" -No -Q "BACKUP DATABASE [WebBanHang-docker] TO DISK = '/var/opt/mssql/$backupFileName' WITH FORMAT;"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Co loi xay ra trong luc backup ben trong container!" -ForegroundColor Red
    exit 1
}

# 2. Tao thu muc backups tren may Windows neu chua co
if (!(Test-Path -Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
}

# 3. Copy file tu container ra may Windows
docker cp "${containerId}:/var/opt/mssql/$backupFileName" "$backupDir\$backupFileName"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "BACKUP THANH CONG!" -ForegroundColor Green
Write-Host "File da duoc luu tai: $backupDir\$backupFileName" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

