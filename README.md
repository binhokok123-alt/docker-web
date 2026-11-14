# Web Bán Hàng - Docker & Kubernetes (High Availability & CI/CD)

Dự án website bán hàng viết bằng **ASP.NET Core 9** kết nối **Microsoft SQL Server**, được container hóa hoàn chỉnh với **Docker**, hỗ trợ **Docker Swarm** (High Availability - Tự phục hồi), **Kubernetes** (PDB, RollingUpdate) và tự động hóa qua **GitHub Actions CI/CD**.

---

## 📑 Bảng mục lục
1. [Các tính năng Container hóa](#-các-tính-năng-container-hóa)
2. [Chế độ 1: Docker Swarm (Khuyên dùng với Docker Desktop)](#1-chế-độ-1-docker-swarm-khuyên-dùng-với-docker-desktop)
3. [Chế độ 2: Docker Compose (Phát triển Local Dev)](#2-chế-độ-2-docker-compose-phát-triển-local-dev)
4. [Chế độ 3: Kubernetes - K8s](#3-chế-độ-3-kubernetes---k8s)
5. [Tự động hóa CI/CD với GitHub Actions, Watchtower & K8s Auto-sync](#4-tự-động-hóa-cicd-với-github-actions-watchtower--k8s-auto-sync)
6. [Sao lưu & Phục hồi Database (Backup & Restore)](#5-sao-lưu--phục-hồi-database-backup--restore)
7. [Tự động co giãn theo tải (Auto-Scaling & HPA)](#6-tự-động-co-giãn-theo-tải-auto-scaling--hpa)

---

## 🐳 Các tính năng Container hóa

* **Multi-stage Build**: Dockerfile tối ưu, tách biệt stage `build` (SDK 9.0) và stage runtime (`aspnet:9.0`), chạy dưới user an toàn `$APP_UID`.
* **High Availability & Self-healing**: 
  * Chạy đồng thời 3 bản sao (`replicas: 3`) web đằng sau cơ chế Ingress Mesh Load Balancer.
  * Khi 1 container/pod bị crash hoặc bị xóa, hệ thống tự động sinh lại bản sao mới ngay lập tức mà không làm gián đoạn người dùng.
* **Shared Data Protection**: Mount volume chung `/app/dataprotection-keys` để đồng bộ key Cookie/Anti-Forgery giữa tất cả các bản sao web.
* **Persistent Data**: SQL Server lưu trữ dữ liệu vào volume/PVC riêng, không bị mất dữ liệu khi restart.
* **Startup Resilience**: Ứng dụng web tích hợp retry 10 lần tự động chờ DB sẵn sàng và tự động chạy `Migrate()` + nạp dữ liệu mẫu (Seed Data).

---

## 1. Chế độ 1: Docker Swarm (Khuyên dùng với Docker Desktop)

> **Đặc điểm:** Chạy **4 containers** (3 Web + 1 SQL Server) hiển thị trực tiếp trên tab **Containers** của Docker Desktop. Cả 3 container web dùng chung cổng `8080`.

### Bước 1: Khởi tạo và Deploy
```powershell
# 1. Bật Docker Swarm (chỉ cần chạy 1 lần duy nhất)
docker swarm init

# 2. Build image web mới nhất
docker compose build

# 3. Triển khai toàn bộ Stack (tên stack: myapp)
docker stack deploy -c docker-compose.yml myapp
```
* **Địa chỉ truy cập Web:** [http://localhost:8080](http://localhost:8080)
* **Kết nối SQL Server:** Host `localhost,1434` | User: `sa` | Password: `Ctt@1234` | DB: `WebBanHang-docker`

### Bước 2: Kiểm tra và giám sát
```powershell
# Xem trạng thái các dịch vụ và số lượng replicas (đang 3/3):
docker stack services myapp

# Xem chi tiết từng container đang chạy:
docker stack ps myapp

# Xem danh sách container qua docker ps:
docker ps

# Xem logs của ứng dụng web:
docker service logs -f myapp_webbanhang

# Xem logs của SQL Server:
docker service logs -f myapp_sqlserver
```

### Bước 3: Test tính năng High Availability (HA)
```powershell
# Test 1: Xóa 1 container web bất kỳ (trên UI Docker Desktop hoặc bằng lệnh):
docker rm -f <CONTAINER_ID>
# Sau đó gõ 'docker ps' sẽ thấy container mới lập tức tự sinh ra, web vẫn vào bình thường.

# Test 2: Scale số lượng container theo ý muốn:
docker service scale myapp_webbanhang=5   # Tăng lên 5 container web
docker service scale myapp_webbanhang=3   # Giảm về 3 container web
```

### Bước 4: Tắt hệ thống Swarm khi không dùng
```powershell
docker stack rm myapp
```

---

## 2. Chế độ 2: Docker Compose (Phát triển Local Dev)

> **Đặc điểm:** Dùng khi phát triển tính năng, khởi chạy nhanh 1 web + 1 database.

### Khởi chạy
```powershell
docker compose up -d --build
```
* **Địa chỉ truy cập:** [http://localhost:8080](http://localhost:8080)

### Kiểm tra logs & Dừng
```powershell
# Xem logs ứng dụng:
docker compose logs -f webbanhang

# Dừng hệ thống (giữ nguyên dữ liệu Database):
docker compose down

# Dừng và XÓA HẾT dữ liệu Database để reset lại từ đầu:
docker compose down -v
```

---

## 3. Chế độ 3: Kubernetes - K8s

> **Đặc điểm:** Mô hình chuẩn Enterprise nằm trong thư mục `k8s/`: Có `PodDisruptionBudget` (PDB), chiến lược `RollingUpdate` không downtime, `LivenessProbe`/`ReadinessProbe`, Service NodePort `30080`.

### Yêu cầu chuẩn bị
1. Đã tích chọn **Enable Kubernetes** trong Settings của Docker Desktop.
2. Tắt Swarm hoặc Compose nếu đang chạy để tránh xung đột cổng:
   ```powershell
   docker stack rm myapp
   docker compose down
   ```

### Bước 1: Deploy lên K8s
```powershell
# Build image trước:
docker compose build

# Apply toàn bộ manifest trong thư mục k8s:
kubectl apply -f k8s/
```

### Bước 2: Mở port để truy cập từ Windows
* **Cách 1 (Khuyên dùng):** Chạy script tự động duy trì kết nối cổng 30080 (tự kết nối lại khi Pod restart/rolling update):
  ```powershell
  ./k8s/port-forward-loop.ps1
  ```
* **Cách 2:** Forward thủ công cả Web (port 30080) và SQL Server (port 1435):
  ```powershell
  # Forward port Web:
  kubectl port-forward service/webbanhang 30080:8080

  # Forward port Database (mở terminal riêng):
  kubectl port-forward service/sqlserver 1435:1433
  ```
* **Hoặc chạy ngầm cả 2 trong 1 terminal PowerShell:**
  ```powershell
  Start-Job { kubectl port-forward service/webbanhang 30080:8080 }
  kubectl port-forward service/sqlserver 1435:1433
  ```
* **Địa chỉ truy cập Web:** [http://localhost:30080](http://localhost:30080)
* **Kết nối SSMS vào SQL Server K8s:** Server `127.0.0.1,1435` | User: `sa` | Password: `Ctt@1234` | Trust Server Certificate: ✓

### Bước 3: Tự động cập nhật Kubernetes khi có code mới (CI/CD Auto-sync)
```powershell
# Bật script ngầm để K8s tự động kéo image mới nhất về khi bạn hoặc team push code lên GitHub:
./k8s/auto-sync-watcher.ps1
```

### Bước 4: Kiểm tra và quản trị K8s
```powershell
# Xem tất cả Pods, Services, PVC, PDB:
kubectl get pods,svc,pvc,pdb

# Xem logs của các Pods web:
kubectl logs -l app=webbanhang -f

# Xem logs của SQL Server:
kubectl logs -l app=sqlserver -f
```

### Bước 5: Test tính năng HA trên Kubernetes
```powershell
# Test 1: Xóa thử 1 Pod web:
kubectl delete pod <TEN_POD_WEBBANHANG>
# K8s sẽ lập tức sinh ra Pod mới bù vào, trang web trên port 30080 không bị rớt kết nối.

# Test 2: Scale số lượng Pod:
kubectl scale deployment webbanhang --replicas=5

# Test 3: Xem ngân sách bảo vệ Pod (PDB):
kubectl get pdb
```

### Bước 6: Dừng tạm thời hoặc Xóa dọn dẹp K8s
* **Dừng tạm (giữ nguyên dữ liệu database, chạy lại không cần tạo lại DB):**
  ```powershell
  kubectl delete deployment webbanhang sqlserver
  kubectl delete service webbanhang sqlserver
  kubectl delete secret sqlserver-secret
  ```
  *Chạy lại khi cần:*
  ```powershell
  kubectl apply -f k8s/
  ./k8s/port-forward-loop.ps1
  ```
* **Xóa hoàn toàn hệ thống và dọn dẹp:**
  ```powershell
  kubectl delete -f k8s/
  ```

---

## 4. Tự động hóa CI/CD với GitHub Actions, Watchtower & K8s Auto-sync

Dự án đã tích hợp pipeline CI/CD tại file `.github/workflows/ci-cd.yml` kết hợp dịch vụ **Watchtower** trong `docker-compose.yml` và bộ **Auto-sync Watcher** cho Kubernetes:

### Quy trình hoạt động hoàn toàn tự động:
1. Khi có bất kỳ thay đổi code nào được push lên GitHub: `git push origin main`.
2. **GitHub Actions** tự động biên dịch .NET 9, đóng gói Docker Image và đẩy image mới nhất lên Docker Hub (`thanhvippro/webbanhang:latest`).
3. **Phía Docker Compose (Port 8080):**
   * Container **Watchtower** đang chạy ngầm định kỳ quét Docker Hub mỗi 10-20s.
   * Khi phát hiện image mới, Watchtower **tự động pull về và restart lại các container web** với code mới ngay lập tức.
4. **Phía Kubernetes (Port 30080):**
   * Script `./k8s/auto-sync-watcher.ps1` phát hiện image mới từ Docker Hub và **tự động kích hoạt RollingUpdate** trên cụm Kubernetes (`kubectl rollout restart deployment/webbanhang`).
   * Kubernetes sẽ lần lượt thay thế từng Pod cũ bằng Pod mới mang code mới mà không làm gián đoạn người dùng (Zero Downtime).

### Hướng dẫn cho người mới clone dự án về:
1. **Nếu chạy Docker Compose:**
   ```powershell
   docker compose up -d
   ```
   *(Docker sẽ tự động tải Watchtower cùng Web & SQL Server về, CI/CD tự kích hoạt 100%)*
2. **Nếu chạy Kubernetes:**
   ```powershell
   # 1. Triển khai tài nguyên K8s
   kubectl apply -f k8s/

   # 2. Mở cổng truy cập (tự động phục hồi kết nối)
   ./k8s/port-forward-loop.ps1

   # 3. (Tùy chọn) Bật tự động cập nhật K8s khi có code mới trên GitHub
   ./k8s/auto-sync-watcher.ps1
   ```

---

## 5. Sao lưu & Phục hồi Database (Backup & Restore)

### PHẦN 1: Nếu bạn đang chạy Kubernetes (K8s)
* **Bước 1: Kích hoạt CronJob tự động (chạy 00:00 mỗi đêm):**
  ```powershell
  kubectl apply -f k8s/sqlserver-backup-cronjob.yaml
  ```
* **Bước 2: Xem danh sách lịch trình CronJob:**
  ```powershell
  kubectl get cronjobs
  ```
* **Bước 3: Chạy test sao lưu NGAY LẬP TỨC (không cần chờ đến đêm):**
  ```powershell
  kubectl create job --from=cronjob/sqlserver-auto-backup test-backup-01
  ```
* **Bước 4: Phục hồi Database (Restore):**
  ```powershell
  .\restore-k8s.ps1
  ```
* **Xóa các Job test backup đã xong:**
  ```powershell
  kubectl delete job test-backup-01
  ```

### PHẦN 2: Nếu bạn đang chạy Docker Compose
* **Sao lưu dữ liệu ngay lập tức:**
  ```powershell
  .\auto-backup.ps1
  ```
* **Phục hồi dữ liệu (Restore) nhanh chóng chỉ bằng 1 lệnh:**
  ```powershell
  .\restore-backup.ps1
  ```

---

## 6. Tự động co giãn theo tải (Auto-Scaling & HPA)

### PHẦN 1: Quan sát Auto-Scaling trên Docker Compose
* **Bước 1: Khởi động Docker Compose:**
  ```powershell
  docker compose up -d
  ```
* **Bước 2: Mở Terminal 1 - Bật bộ giám sát Auto-Scaler:**
  ```powershell
  .\auto-scale-compose.ps1
  ```
* **Bước 3: Mở Terminal 2 - Bắn tải liên tục để kiểm tra:**
  ```powershell
  1..10 | ForEach-Object {
      Start-Job -ScriptBlock {
          while ($true) {
              try { Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing | Out-Null } catch {}
          }
      }
  }
  ```
* 👉 **Hiện tượng quan sát được:**
  * Tại **Terminal 1**: Khi CPU trung bình vượt ngưỡng 40%, script nhấp nháy cảnh báo: `[ALERT] CPU vuot nguong 40%! Tien hanh AUTO-SCALE UP len 5 containers...`.
  * Gõ `docker ps` sẽ thấy số lượng container web tự động tăng từ 2 lên 5 container.
  * Khi dừng bắn tải: Chạy `Get-Job | Remove-Job -Force`. Vài giây sau khi CPU hạ dưới 15%, script tự động thu gọn về lại 2 container.

### PHẦN 2: Quan sát HPA chính thống trên Kubernetes (K8s)
* **Bước 1: Khởi động và cài đặt metrics-server (chỉ cần chạy lần đầu):**
  ```powershell
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl patch deployment metrics-server -n kube-system --patch-file k8s/metrics-server-patch.yaml
  ```
  *Áp dụng cấu hình HPA:*
  ```powershell
  kubectl apply -f k8s/webbanhang-hpa.yaml
  ```
* **Bước 2: Mở 2 màn hình quan sát K8s:**
  * *Màn hình A (Theo dõi HPA):*
    ```powershell
    kubectl get hpa -w
    ```
  * *Màn hình B (Theo dõi số Pod):*
    ```powershell
    kubectl get pods -w
    ```
* **Bước 3: Bắn tải vào cổng 30080 của K8s:**
  ```powershell
  1..15 | ForEach-Object {
      Start-Job -ScriptBlock {
          while ($true) {
              try { Invoke-WebRequest -Uri "http://localhost:30080" -UseBasicParsing | Out-Null } catch {}
          }
      }
  }
  ```
* 👉 **Hiện tượng quan sát được:**
  * Tại **Màn hình A**: Cột `TARGETS` CPU từ 0%/50% sẽ nhảy vọt lên cao.
  * Tại **Màn hình B**: Kubernetes lập tức tự động sinh thêm Pod mới, cột `REPLICAS` tăng dần từ 2 -> 3 -> 4 -> tối đa 6 Pods!
  * Khi dừng bắn tải: Chạy `Get-Job | Remove-Job -Force`. Sau thời gian ổn định (khoảng 3-5 phút), K8s sẽ tự động xóa bớt các Pod thừa và co gọn về lại 2 Pods.
