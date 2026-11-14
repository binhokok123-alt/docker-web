# Script tu dong dong bo Kubernetes khi Watchtower cap nhat Compose
$lastImageId = ""

while ($true) {
    try {
        $currentImageId = docker inspect thanhvippro/webbanhang:latest --format '{{.Id}}' 2>$null
        if ($currentImageId -and ($currentImageId -ne $lastImageId)) {
            if ($lastImageId -ne "") {
                Write-Host "[Auto-Sync] Phat hien image moi duoc Watchtower pull ve! Dang dong bo sang Kubernetes..." -ForegroundColor Cyan
                # Rollout restart k8s deployment
                kubectl rollout restart deployment/webbanhang
                Write-Host "[Auto-Sync] Da kich hoat RollingUpdate tren Kubernetes thanh cong!" -ForegroundColor Green
            }
            $lastImageId = $currentImageId
        }
    } catch {
        # ignore transient errors
    }
    Start-Sleep -Seconds 5
}
