# Script tu dong Restore database cho Kubernetes (K8s)

Write-Host "Dang tim ban backup moi nhat tren Pod SQL Server cua K8s..." -ForegroundColor Cyan

# 1. Tim file backup moi nhat ben trong Pod sqlserver
$latestBackup = kubectl exec deployment/sqlserver -- /bin/bash -c "ls -t /var/opt/mssql/backup_auto_*.bak 2>/dev/null | head -n 1"
$latestBackup = "$latestBackup".Trim()

if (-not $latestBackup) {
    Write-Host "Khong tim thay file backup nao trong Pod SQL Server!" -ForegroundColor Red
    exit 1
}

Write-Host "Dang tien hanh phuc hoi tu file: $latestBackup..." -ForegroundColor Cyan

# 2. Thuc hien RESTORE trong SQL Server cua K8s
$sql = @"
ALTER DATABASE [WebBanHang-docker] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [WebBanHang-docker] FROM DISK = '$latestBackup' WITH REPLACE;
ALTER DATABASE [WebBanHang-docker] SET MULTI_USER;
"@

kubectl exec deployment/sqlserver -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Binhok@123456" -No -Q "$sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "PHUC HOI K8S THANH CONG 100%!" -ForegroundColor Green
    Write-Host "Du lieu da duoc khoi phuc tu file: $latestBackup" -ForegroundColor Green
    Write-Host "Hay quay lai trinh duyet va bam F5 de xem ket qua!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host "Co loi xay ra khi restore tren K8s!" -ForegroundColor Red
    kubectl exec deployment/sqlserver -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "Binhok@123456" -No -Q "ALTER DATABASE [WebBanHang-docker] SET MULTI_USER;" 2>$null
}
