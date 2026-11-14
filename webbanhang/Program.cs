using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using webbanhang.Data;

var builder = WebApplication.CreateBuilder(args);

// Đăng ký DbContext với SQL Server
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection"),
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
