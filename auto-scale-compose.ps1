# Script Mo phong HPA (Auto-Scaling) cho Docker Compose

$MIN_REPLICAS = 2
$MAX_REPLICAS = 5
$SCALE_UP_THRESHOLD = 40.0   # Neu CPU trung binh vuot 40% thi scale up
$SCALE_DOWN_THRESHOLD = 15.0 # Neu CPU trung binh duoi 15% thi scale down
$COOLDOWN_SECONDS = 15       # Thoi gian cho sau khi scale

Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   DOCKER COMPOSE AUTO-SCALER (MO PHONG HPA CUA K8S)     " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Nguong Scale Up   : CPU > $SCALE_UP_THRESHOLD % (Tang len $MAX_REPLICAS containers)" -ForegroundColor Gray
Write-Host "Nguong Scale Down : CPU < $SCALE_DOWN_THRESHOLD % (Giam ve $MIN_REPLICAS containers)" -ForegroundColor Gray
Write-Host "Nhan Ctrl + C de dung theo doi`n" -ForegroundColor Gray

$lastScaleTime = [DateTime]::MinValue

while ($true) {
    # 1. Lay danh sach container webbanhang
    $containers = docker ps --filter "name=webbanhangdemo-webbanhang" --format "{{.Names}}"
    $containerCount = ($containers | Measure-Object).Count

    if ($containerCount -eq 0) {
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - Khong tim thay container webbanhang nao dang chay!" -ForegroundColor Red
        Start-Sleep -Seconds 3
        continue
    }

    # 2. Lay % CPU cua cac container webbanhang
    $stats = docker stats --no-stream --format "{{.Name}}:{{.CPUPerc}}" | Where-Object { $_ -match "webbanhang" }
    
    $totalCpu = 0.0
    $count = 0

    foreach ($line in $stats) {
        $parts = $line -split ":"
        if ($parts.Length -ge 2) {
            $cpuStr = $parts[1].Replace("%", "").Trim()
            [double]$cpuVal = 0
            if ([double]::TryParse($cpuStr, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$cpuVal)) {
                $totalCpu += $cpuVal
                $count++
            }
        }
    }

    $avgCpu = if ($count -gt 0) { [math]::Round($totalCpu / $count, 2) } else { 0.0 }
    $now = Get-Date
    $timeSinceLastScale = ($now - $lastScaleTime).TotalSeconds

    # In trang thai he thong
    $statusColor = if ($avgCpu -gt $SCALE_UP_THRESHOLD) { "Red" } else { "Green" }
    Write-Host ("[{0}] Dang chay: {1} containers | CPU trung binh: {2}%" -f $now.ToString("HH:mm:ss"), $containerCount, $avgCpu) -ForegroundColor $statusColor

    # 3. Kiem tra dieu kien SCALE UP
    if ($avgCpu -gt $SCALE_UP_THRESHOLD -and $containerCount -lt $MAX_REPLICAS -and $timeSinceLastScale -gt $COOLDOWN_SECONDS) {
        Write-Host ">>> [ALERT] CPU vuot nguong $SCALE_UP_THRESHOLD%! Tien hanh AUTO-SCALE UP len $MAX_REPLICAS containers..." -ForegroundColor Magenta
        docker compose up -d --scale webbanhang=$MAX_REPLICAS --no-recreate | Out-Null
        
        # Reload lai Nginx de cap nhat danh sach container moi
        $nginxId = docker ps --filter "name=nginx" --format "{{.ID}}"
        if ($nginxId) { docker exec $nginxId nginx -s reload 2>$null | Out-Null }
        
        $lastScaleTime = Get-Date
        Write-Host ">>> [THANH CONG] Da scale len $MAX_REPLICAS containers!`n" -ForegroundColor Green
    }
    # 4. Kiem tra dieu kien SCALE DOWN
    elseif ($avgCpu -lt $SCALE_DOWN_THRESHOLD -and $containerCount -gt $MIN_REPLICAS -and $timeSinceLastScale -gt $COOLDOWN_SECONDS) {
        Write-Host ">>> [INFO] CPU ha duoi $SCALE_DOWN_THRESHOLD%. Tien hanh AUTO-SCALE DOWN ve $MIN_REPLICAS containers..." -ForegroundColor Yellow
        docker compose up -d --scale webbanhang=$MIN_REPLICAS | Out-Null
        
        # Reload lai Nginx
        $nginxId = docker ps --filter "name=nginx" --format "{{.ID}}"
        if ($nginxId) { docker exec $nginxId nginx -s reload 2>$null | Out-Null }
        
        $lastScaleTime = Get-Date
        Write-Host ">>> [THANH CONG] Da thu gon ve $MIN_REPLICAS containers!`n" -ForegroundColor Cyan
    }

    Start-Sleep -Seconds 2
}
