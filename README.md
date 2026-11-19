# Web Bán Hàng - Docker & Kubernetes (High Availability & CI/CD)

Dự án website bán hàng viết bằng **ASP.NET Core 9** kết nối **Microsoft SQL Server**, được container hóa hoàn chỉnh với **Docker**, hỗ trợ **Docker Swarm** (High Availability - Tự phục hồi), **Kubernetes** (PDB, RollingUpdate) và tự động hóa qua **GitHub Actions CI/CD**.

---

## 📑 Bảng mục lục
1. [Các tính năng Container hóa](#-các-tính-năng-container-hóa)
2. [Chế độ 1: Docker Swarm (Khuyên dùng với Docker Desktop)](#1-chế-độ-1-docker-swarm-khuyên-dùng-với-docker-desktop)
3. [Chế độ 2: Docker Compose (Phát triển Local Dev)](#2-chế-độ-2-docker-compose-phát-triển-local-dev)
4. [Chế độ 3: Kubernetes - K8s](#3-chế-độ-3-kubernetes---k8s)
5. [Tự động hóa CI/CD với GitHub Actions & K8s Auto-sync](#4-tự-động-hóa-cicd-với-github-actions--k8s-auto-sync)
6. [Sao lưu & Phục hồi Database (Backup & Restore)](#5-sao-lưu--phục-hồi-database-backup--restore)
7. [Tự động co giãn theo tải (Auto-Scaling & HPA)](#6-tự-động-co-giãn-theo-tải-auto-scaling--hpa)
8. [Hệ thống Giám sát & Dashboard (Prometheus & Grafana)](#7-hệ-thống-giám-sát--dashboard-prometheus--grafana-monitoring)
9. [Bảo mật & Quản lý Bí mật tập trung (HashiCorp Vault)](#8-bảo-mật--quản-lý-bí-mật-tập-trung-hashicorp-vault---devsecops)

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
* **Kết nối SQL Server:** Host `localhost,1434` | User: `sa` | Password: `Binhok@123456` | DB: `WebBanHang-docker`

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

> **Đặc điểm:** Triển khai cụm dịch vụ hoàn chỉnh gồm: 3 Replicas Web, Nginx Cân bằng tải, SQL Server, và Két sắt HashiCorp Vault. Tự động tải bản mới từ Docker Hub nhờ chính sách `pull_policy: always`.

### Khởi chạy (Dành cho thành viên trong nhóm)
* **Nếu bạn đã có sẵn thư mục dự án trên máy:**
  ```powershell
  git pull
  docker compose up -d
  ```
* **Nếu là máy mới tinh lần đầu tải dự án về:**
  ```powershell
  git clone <LINK_REPO_GITHUB>
  cd webbanhangdemo
  docker compose up -d
  ```
*(Docker Compose sẽ tự động tải các Image đã build sẵn về máy, tự động tạo DB và khởi động Vault mà không cần bạn phải cấu hình hay build gì thêm).*

* **Địa chỉ truy cập Web bán hàng:** [http://localhost:8080](http://localhost:8080)
  * Tài khoản Admin: `admin` / Mật khẩu: `123`
  * Tài khoản User: Bấm Đăng ký tài khoản bất kỳ để trải nghiệm quyền xem.
* **Giao diện Két sắt HashiCorp Vault:** [http://localhost:8200](http://localhost:8200)
  * Phương thức: **Token** | Khóa: **`root`**
* **Kết nối SQL Server từ SSMS:** `localhost,1434` | User: `sa` | Password: `Binhok@123456`

### Kiểm tra logs & Dừng
```powershell
# Xem logs ứng dụng:
docker compose logs -f webbanhang

# Xem trạng thái kết nối Vault của Web:
docker compose logs webbanhang | Select-String "VAULT"

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
* **Kết nối SSMS vào SQL Server K8s:** Server `127.0.0.1,1435` | User: `sa` | Password: `Binhok@123456` | Trust Server Certificate: ✓

### Bước 3: Tự động cập nhật Kubernetes khi có code mới (CI/CD Auto-updater)
> Pod **`k8s-auto-updater`** (trong file `k8s/k8s-auto-updater.yaml`) đã tự động chạy ngầm bên trong cụm K8s. Cứ mỗi 15 giây nó tự kiểm tra Docker Hub, nếu có bản build mới từ GitHub Actions là nó tự động kích hoạt `kubectl rollout restart deployment/webbanhang` mà bạn không cần chạy lệnh thủ công nào!

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

## 4. Tự động hóa CI/CD với GitHub Actions, Docker Compose & K8s Auto-updater

Dự án đã tích hợp pipeline CI/CD tại file `.github/workflows/ci-cd.yml` kết hợp cấu hình `pull_policy: always` trong `docker-compose.yml` và Pod **k8s-auto-updater** cho Kubernetes:

### Quy trình hoạt động hoàn toàn tự động:
1. Khi có bất kỳ thay đổi code nào được push lên GitHub: `git push origin main`.
2. **GitHub Actions** tự động biên dịch .NET 9, đóng gói Docker Image và đẩy image mới nhất lên Docker Hub (`thanhvippro/webbanhang:latest`).
3. **Phía Docker Compose (Port 8080):**
   * Cấu hình `pull_policy: always` giúp Docker Compose tự động kiểm tra và kéo image mới nhất từ Docker Hub về mỗi khi bạn gõ `docker compose up -d`.
4. **Phía Kubernetes (Port 30080):**
   * Pod `k8s-auto-updater` chạy ngầm phát hiện image mới từ Docker Hub và **tự động kích hoạt RollingUpdate** trên cụm Kubernetes (`kubectl rollout restart deployment/webbanhang`).
   * Kubernetes sẽ lần lượt thay thế từng Pod cũ bằng Pod mới mang code mới mà không làm gián đoạn người dùng (Zero Downtime).

### Hướng dẫn cho người mới clone dự án về:
1. **Nếu chạy Docker Compose:**
   ```powershell
   docker compose up -d
   ```
   *(Docker sẽ tự động tải Image mới nhất cùng Web, SQL Server và Vault về chạy)*
2. **Nếu chạy Kubernetes:**
   ```powershell
   # 1. Triển khai tài nguyên K8s
   kubectl apply -f k8s/

   # 2. Mở cổng truy cập (tự động phục hồi kết nối)
   ./k8s/port-forward-loop.ps1
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

---

## 7. Hệ thống Giám sát & Dashboard (Prometheus & Grafana Monitoring)

Dự án đã tích hợp sẵn hệ thống quan sát chuyên nghiệp (Monitoring Stack) theo chuẩn Cloud-Native nằm trong thư mục `k8s/monitoring/`:
* **Prometheus:** Thu thập chỉ số CPU, RAM, Network Traffic, Pod status từ cụm K8s.
* **Kube-State-Metrics (KSM):** Cung cấp trạng thái chi tiết của Deployment, Pods, HPA.
* **Grafana:** Trực quan hóa dữ liệu thời gian thực thành biểu đồ, **tự động nạp sẵn Dashboard** (Provisioning) không cần cấu hình bằng tay.

---

### Bước 1: Khởi chạy bộ Giám sát (Chỉ 1 lệnh duy nhất)
Mở PowerShell tại thư mục dự án và chạy:
```powershell
kubectl apply -f k8s/monitoring/
```
> Lệnh này sẽ tự động triển khai Prometheus, Kube-State-Metrics và Grafana lên cụm K8s.

### Bước 2: Kiểm tra các Pod giám sát đã chạy
```powershell
kubectl get pods -l "app in (prometheus, grafana)"
```
*(Chờ khoảng 30s - 1 phút để các Pod chuyển sang trạng thái `Running`)*.

### Bước 3: Truy cập Grafana Dashboard
* **Địa chỉ truy cập Grafana:** [http://localhost:32000](http://localhost:32000)
* **Tài khoản đăng nhập:**
  * **Username:** `admin`
  * **Password:** `admin`
* **Vào xem Dashboard trực tiếp:**
  1. Vào menu bên trái chọn **Dashboards** (hoặc biểu tượng 4 ô vuông).
  2. Bấm vào Dashboard: **`WebBanHang - Giam Sat Tai & HPA`**.
  3. Bạn sẽ thấy 4 biểu đồ hiển thị thời gian thực:
     * **Số Pod WebBanHang Đang Chạy** (Hiện số lượng 3 -> 6 Pods).
     * **CPU Pod WebBanHang vs Ngưỡng HPA (50%)**.
     * **RAM Tiêu Thụ** (WebBanHang & SQL Server).
     * **Lưu Lượng Mạng** (Network Traffic).

---

### Bước 4: Thử nghiệm Bắn tải và Quan sát Biểu đồ nhảy số
Để bạn của bạn thấy biểu đồ tăng vọt và K8s tự động scale Pods từ 3 lên 6:

1. **Bắn tải (Mở Terminal chạy lệnh):**
   ```powershell
   1..15 | ForEach-Object {
       Start-Job -ScriptBlock {
           while ($true) {
               try { Invoke-WebRequest -Uri "http://localhost:30080" -UseBasicParsing | Out-Null } catch {}
           }
       }
   }
   ```
2. **Quan sát trên Grafana:**
   * Cột CPU sẽ vọt lên qua vạch 50%.
   * Ô "Số Pod WebBanHang Đang Chạy" sẽ nhảy từ **3 Pods** lên **6 Pods**!
3. **Tắt bắn tải để hạ nhiệt:**
   ```powershell
   Get-Job | Remove-Job -Force
   ```
   *(Sau khoảng 1-2 phút, CPU hạ nhiệt và HPA sẽ tự động co gọn Pods về lại 3 bản sao ban đầu).*

---

### Xóa/Dọn dẹp hệ thống Monitoring khi không dùng:
```powershell
kubectl delete -f k8s/monitoring/
```

---

## 8. Bảo mật & Quản lý Bí mật tập trung (HashiCorp Vault - DevSecOps)

Dự án áp dụng giải pháp quản trị bí mật chuẩn Enterprise **HashiCorp Vault** để giải quyết triệt để nguy cơ lộ mật khẩu Database:
* **Zero Trust Security:** Mật khẩu SQL Server không lưu trong mã nguồn, không lưu trên Git, mà được cất trong két sắt Vault tại đường dẫn `secret/webbanhang`.
* **K8s Secret Masking:** Trên Kubernetes, Token kết nối Vault được mã hóa bên trong K8s Secret (`vault-secret`), không lộ bất kỳ token nào trong file Deployment.
* **Auto-Provisioning:** Tự động khởi tạo secret khi hệ thống vừa bật lên (Job trên K8s và Container trên Compose).
* **Resilience & Fallback:** Web tích hợp cơ chế tự phục hồi thông minh. Nếu Vault gặp sự cố hoặc bị tắt, Web tự động chuyển sang chuỗi kết nối dự phòng để duy trì hoạt động 100% không downtime.

---

### PHẦN 1: Nếu chạy trên Docker Compose
* **Mở giao diện Két sắt Vault:** [http://localhost:8200](http://localhost:8200) (Token: **`root`**)
* **Kiểm tra Web đã nhận Secret:**
  ```powershell
  docker compose logs webbanhang | Select-String "VAULT"
  ```
* **Kịch bản Demo Tự phục hồi:** Tắt Vault (`docker compose stop vault`) -> restart web (`docker compose restart webbanhang`) -> Web vẫn sống 100%!

---

### PHẦN 2: Nếu chạy trên Kubernetes (K8s)
1. **Khởi chạy Vault lên cụm K8s:**
   ```powershell
   kubectl apply -f k8s/vault.yaml
   kubectl apply -f k8s/webbanhang-deployment.yaml
   ```
2. **Kiểm tra các Pod Vault và Job khởi tạo đã hoàn thành:**
   ```powershell
   kubectl get pods -l "app=vault"
   kubectl get jobs vault-init-job
   ```
3. **Mở giao diện Két sắt Vault K8s từ máy Windows:**
   * **Địa chỉ:** [http://localhost:32200](http://localhost:32200)
   * **Method:** Chọn **Token** | **Token:** Nhập **`root`** -> Bấm **Sign In**.
   * Bấm vào **`secret/`** -> **`webbanhang`** để thấy chuỗi kết nối an toàn.
4. **Kiểm tra các Pod Web K8s đã lấy mật khẩu từ Vault:**
   ```powershell
   kubectl logs -l app=webbanhang | Select-String "VAULT"
   ```
   👉 Sẽ in ra: `[VAULT] Ket noi HashiCorp Vault thanh cong! Da lay chuoi ket noi DB tu Vault.`
