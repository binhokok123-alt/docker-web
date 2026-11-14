while ($true) {
    try {
        kubectl port-forward --address 0.0.0.0 svc/webbanhang 30080:8080
    } catch {
        Write-Host "Reconnecting port-forward..."
    }
    Start-Sleep -Seconds 2
}
