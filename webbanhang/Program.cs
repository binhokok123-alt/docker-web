using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using webbanhang.Data;

var builder = WebApplication.CreateBuilder(args);

// =========================================================================================
// [CƠ CHẾ RESILIENCE & FALLBACK - BẢO MẬT VÀ TỰ PHỤC HỒI KHI VAULT GẶP SỰ CỐ]
// =========================================================================================

// BƯỚC 1 (PHƯƠNG ÁN B - FALLBACK DỰ PHÒNG):
// Luôn nạp sẵn chuỗi kết nối mặc định từ appsettings.json hoặc biến môi trường K8s/Compose.
// Nếu Vault gặp sự cố hoặc bị tắt, biến này sẽ được giữ nguyên để Web vẫn sống 100%.
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");

// Lấy địa chỉ và Token kết nối tới két sắt HashiCorp Vault
var vaultAddress = builder.Configuration["Vault:Address"] ?? Environment.GetEnvironmentVariable("Vault__Address");
var vaultToken = builder.Configuration["Vault:Token"] ?? Environment.GetEnvironmentVariable("Vault__Token") ?? "root";

// BƯỚC 2 (PHƯƠNG ÁN A - ƯU TIÊN KẾT NỐI VAULT):
// Nếu có cấu hình địa chỉ Vault, ứng dụng sẽ ưu tiên kết nối vào két sắt để lấy mật khẩu chính thức.
if (!string.IsNullOrEmpty(vaultAddress))
{
    // Vòng lặp thử lại tối đa 5 lần (Retry Pattern) phòng trường hợp Vault đang khởi động
    for (int retry = 0; retry < 5; retry++)
    {
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(3) };
            client.DefaultRequestHeaders.Add("X-Vault-Token", vaultToken);

            // Thử lấy secret theo chuẩn KV v2 trước: /v1/secret/data/webbanhang
            var response = client.GetAsync($"{vaultAddress.TrimEnd('/')}/v1/secret/data/webbanhang").GetAwaiter().GetResult();
            
            // Nếu trả về 404 thì thử tiếp theo chuẩn KV v1: /v1/secret/webbanhang
            if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                response = client.GetAsync($"{vaultAddress.TrimEnd('/')}/v1/secret/webbanhang").GetAwaiter().GetResult();
            }

            if (response.IsSuccessStatusCode)
            {
                var json = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
                using var doc = System.Text.Json.JsonDocument.Parse(json);
                
                // Tự động phân giải cấu trúc JSON trả về của cả Vault KV v2 và KV v1
                System.Text.Json.JsonElement secretData = default;
                if (doc.RootElement.TryGetProperty("data", out var dataProp))
                {
                    if (dataProp.TryGetProperty("data", out var nestedData))
                    {
                        secretData = nestedData; // Định dạng KV v2
                    }
                    else
                    {
                        secretData = dataProp; // Định dạng KV v1
                    }
                }

                // Nếu tìm thấy key ConnectionStrings__DefaultConnection trong Vault:
                if (secretData.ValueKind != System.Text.Json.JsonValueKind.Undefined &&
                    secretData.TryGetProperty("ConnectionStrings__DefaultConnection", out var csVal))
                {
                    var secretConn = csVal.GetString();
                    if (!string.IsNullOrEmpty(secretConn))
                    {
                        // GHI ĐÈ mật khẩu lấy từ Vault vào connectionString (Ưu tiên số 1)
                        connectionString = secretConn;
                        Console.WriteLine("[VAULT] Ket noi HashiCorp Vault thanh cong! Da lay chuoi ket noi DB tu Vault.");
                        break; // Lấy thành công thì thoát vòng lặp ngay
                    }
                }
            }
            
            // Nếu chưa lấy được (do job khởi tạo đang chạy), chờ 1 giây rồi thử lại
            Thread.Sleep(1000);
        }
        catch (Exception ex)
        {
            // BƯỚC 3 (KÍCH HOẠT FALLBACK KHI VAULT BỊ SẬP):
            // Nếu Vault bị tắt nguồn hoặc gặp lỗi mạng, khối catch này sẽ tóm lấy lỗi
            // để ứng dụng KHÔNG BỊ CRASH, và tự động giữ nguyên chuỗi kết nối dự phòng (Bước 1).
            if (retry == 4)
            {
                Console.WriteLine($"[VAULT RESILIENCE] Khong the ket noi Vault ({ex.Message}). Tu dong dung connection string du phong!");
            }
            Thread.Sleep(1000);
        }
    }
}

// BƯỚC 4 (KẾT NỐI DATABASE AN TOÀN):
// Đăng ký DbContext với chuỗi kết nối hợp lệ (lấy từ Vault hoặc từ Fallback dự phòng)
// kèm cơ chế Retry On Failure của Entity Framework Core.
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(connectionString,
        sqlOptions => sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 10,
            maxRetryDelay: TimeSpan.FromSeconds(10),
            errorNumbersToAdd: null)));

builder.Services.AddControllersWithViews();
builder.Services.AddSession();
builder.Services.AddHttpContextAccessor();

builder.Services.AddDataProtection()
    .PersistKeysToFileSystem(new DirectoryInfo("/app/dataprotection-keys"))
    .SetApplicationName("webbanhang");

var app = builder.Build();


//Tự động chạy migration khi app khởi động
// using (var scope = app.Services.CreateScope())
//{
//    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
//    try { db.Database.Migrate(); } catch { }
//}


// Nếu không phải môi trường Development thì dùng trang lỗi thân thiện thay vì hiện chi tiết lỗi
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
}


// Tự động chạy migration khi app khởi động
// Nếu database chưa có thì tạo mới, nếu có rồi thì cập nhật schema
// Retry tối đa 10 lần, mỗi lần cách nhau 5 giây (phòng trường hợp sqlserver chưa sẵn sàng)
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    var retries = 10;
    while (retries > 0)
    {
        try
        {
            db.Database.Migrate(); // Chạy migration

            // Tự động tạo sẵn tài khoản admin nếu chưa có
            if (!db.Users.Any(u => u.Username.ToLower() == "admin"))
            {
                db.Users.Add(new webbanhang.Models.User
                {
                    Username = "admin",
                    Password = "123",
                    Email = "admin@shop.com"
                });
                db.SaveChanges();
            }

            break; // Thành công thì thoát vòng lặp
        }
        catch
        {
            retries--;
            Thread.Sleep(5000); // Đợi 5 giây rồi thử lại
        }
    }
}


app.UseRouting();
app.UseSession();
app.UseAuthorization();
app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();

app.Run();
