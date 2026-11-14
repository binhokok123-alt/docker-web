# Web Bán Hàng - Docker & Kubernetes (High Availability & CI/CD)

Dự án website bán hàng viết bằng **ASP.NET Core 9** kết nối **Microsoft SQL Server**, được container hóa hoàn chỉnh với **Docker**, hỗ trợ **Docker Swarm** (High Availability - Tự phục hồi), **Kubernetes** (PDB, RollingUpdate) và tự động hóa qua **GitHub Actions CI/CD**.

---

## 📑 Bảng mục lục
1. [Các tính năng Container hóa](#-các-tính-năng-container-hóa)
2. [Chế độ 1: Docker Swarm (Khuyên dùng với Docker Desktop)](#1-chế-độ-1-docker-swarm-khuyên-dùng-với-docker-desktop)
3. [Chế độ 2: Docker Compose (Phát triển Local Dev)](#2-chế-độ-2-docker-compose-phát-triển-local-dev)
4. [Chế độ 3: Kubernetes - K8s](#3-chế-độ-3-kubernetes---k8s)
5. [Tự động hóa CI/CD với GitHub Actions](#4-tự-động-hóa-cicd-với-github-actions)

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

### Bước 2: Mở port 30080 để truy cập từ Windows
```powershell
kubectl port-forward --address 0.0.0.0 svc/webbanhang 30080:8080
```
* **Địa chỉ truy cập:** [http://localhost:30080](http://localhost:30080)

### Bước 3: Kiểm tra và quản trị K8s
```powershell
# Xem tất cả Pods, Services, PVC, PDB:
kubectl get pods,svc,pvc,pdb

# Xem logs của các Pods web:
kubectl logs -l app=webbanhang -f

# Xem logs của SQL Server:
kubectl logs -l app=sqlserver -f
```

### Bước 4: Test tính năng HA trên Kubernetes
```powershell
# Test 1: Xóa thử 1 Pod web:
kubectl delete pod <TEN_POD_WEBBANHANG>
# K8s sẽ lập tức sinh ra Pod mới bù vào, trang web trên port 30080 không bị rớt kết nối.

# Test 2: Scale số lượng Pod:
kubectl scale deployment webbanhang --replicas=5

# Test 3: Xem ngân sách bảo vệ Pod (PDB):
kubectl get pdb
```

### Bước 5: Xóa dọn dẹp K8s khi không dùng
```powershell
kubectl delete -f k8s/
```

---

## 4. Tự động hóa CI/CD với GitHub Actions & Watchtower (Tự động cập nhật Container)

Dự án đã tích hợp pipeline CI/CD tại file `.github/workflows/ci-cd.yml` kết hợp dịch vụ **Watchtower** trong `docker-compose.yml`:
* **Quy trình hoạt động hoàn toàn tự động:**
  1. Khi bạn sửa code và gõ `git push origin main`.
  2. GitHub Actions tự động kiểm tra cú pháp, build .NET và đóng gói Docker image, sau đó đẩy image `webbanhang:latest` lên **Docker Hub**.
  3. Dịch vụ **Watchtower** đang chạy ngầm trong máy sẽ kiểm tra định kỳ mỗi 30s. Khi thấy image mới trên Docker Hub, Watchtower sẽ **tự động kéo (pull) về và restart container web với code mới ngay lập tức**, bạn chỉ việc F5 lại trình duyệt!
