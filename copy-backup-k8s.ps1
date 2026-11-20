# Script tu dong copy file backup moi nhat tu K8s ve thu muc backups tren may tinh Windows
# Duoc viet boi Antigravity

Write-Host "Dang tim Pod SQL Server tren K8s..." -ForegroundColor Cyan

# 1. Tim Pod sqlserver (tranh nham voi cac pod sqlserver-auto-backup)
$allPods = kubectl get pods -o name
$sqlPodLine = $allPods | Where-Object { $_ -match "pod/sqlserver-[a-z0-9]+-[a-z0-9]+" } | Select-Object -First 1

if (-not $sqlPodLine) {
    # Thu tim theo cach khac neu khong khop mau
    $sqlPodLine = $allPods | Where-Object { $_ -match "pod/sqlserver-" -and $_ -notmatch "auto-backup" } | Select-Object -First 1
}

if (-not $sqlPodLine) {
    Write-Host "Khong tim thay Pod SQL Server dang chay! Vui long kiem tra bang 'kubectl get pods'." -ForegroundColor Red
    exit 1
}

$pod = $sqlPodLine.ToString().Replace("pod/", "").Trim()
Write-Host "-> Da tim thay Pod: $pod" -ForegroundColor Green

# 2. Tim file backup moi nhat ben trong Pod
Write-Host "Dang tim file backup moi nhat..." -ForegroundColor Cyan
$file = (kubectl exec $pod -- /bin/bash -c "ls -t /var/opt/mssql/backup_auto_*.bak 2>/dev/null | head -n 1").Trim()

if (-not $file) {
    Write-Host "Khong tim thay file backup nao ben trong Pod!" -ForegroundColor Red
    exit 1
}

$fileName = Split-Path $file -Leaf
$localBackupDir = "$PSScriptRoot\backups"

# Tao thu muc backups neu chua co
if (!(Test-Path -Path $localBackupDir)) {
    New-Item -ItemType Directory -Path $localBackupDir | Out-Null
}

# 3. Copy file tu K8s Pod ve thu muc backups tren Windows
Write-Host "Dang copy file $fileName ve thu muc backups tren may tinh..." -ForegroundColor Cyan
kubectl cp "${pod}:${file}" "$localBackupDir\$fileName"

if (Test-Path "$localBackupDir\$fileName") {
    $size = (Get-Item "$localBackupDir\$fileName").Length / 1MB
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "COPY FILE BACKUP VE MAY THANH CONG 100%!" -ForegroundColor Green
    Write-Host "Vi tri file: $localBackupDir\$fileName" -ForegroundColor Green
    Write-Host ("Dung luong: {0:N2} MB" -f $size) -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host "Co loi xay ra khi copy file tu K8s!" -ForegroundColor Red
}
