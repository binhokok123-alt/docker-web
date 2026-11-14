# Script tu dong Restore database tu ban backup moi nhat
# Duoc viet boi Antigravity

$backupDir = "$PSScriptRoot\backups"

# 1. Tim container SQL Server dang chay
$containerId = docker ps --filter "ancestor=mcr.microsoft.com/mssql/server:2022-latest" --format "{{.ID}}"
if (-not $containerId) {
    Write-Host "Khong tim thay container SQL Server dang chay!" -ForegroundColor Red
    exit 1
}

# 2. Tim file backup moi nhat trong thu muc backups
$latestBackup = Get-ChildItem -Path $backupDir -Filter "*.bak" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $latestBackup) {
    Write-Host "Khong tim thay file backup nao trong thu muc $backupDir!" -ForegroundColor Red
    exit 1
}

$backupFileName = $latestBackup.Name
Write-Host "Dang chuan bi phuc hoi tu ban backup moi nhat: $backupFileName..." -ForegroundColor Cyan

# 3. Dam bao file backup co trong container
docker cp "$($latestBackup.FullName)" "${containerId}:/var/opt/mssql/$backupFileName"

# 4. Chay lenh RESTORE trong SQL Server
$restoreSql = @"
ALTER DATABASE [WebBanHang-docker] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [WebBanHang-docker] FROM DISK = '/var/opt/mssql/$backupFileName' WITH REPLACE;
ALTER DATABASE [WebBanHang-docker] SET MULTI_USER;
"@

docker exec $containerId /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Binhok@123456" -No -Q "$restoreSql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "PHUC HOI (RESTORE) THANH CONG 100%!" -ForegroundColor Green
    Write-Host "Du lieu da duoc khoi phuc tu file: $backupFileName" -ForegroundColor Green
    Write-Host "Hay quay lai trinh duyet va bam F5 de xem ket qua!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host "Co loi xay ra trong qua trinh restore!" -ForegroundColor Red
    # Dam bao dua database ve lai MULTI_USER neu bi loi
    docker exec $containerId /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Binhok@123456" -No -Q "ALTER DATABASE [WebBanHang-docker] SET MULTI_USER;" 2>$null
}
