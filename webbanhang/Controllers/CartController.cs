using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using webbanhang.Data;
using webbanhang.Models;

namespace webbanhang.Controllers
{
    public class CartController : Controller
    {
        private readonly ApplicationDbContext _context;
        private const string CartCookieKey = "ShopOnline_Cart";

        public CartController(ApplicationDbContext context)
        {
            _context = context;
        }

        // Lấy giỏ hàng từ Cookie trình duyệt (đảm bảo Pod nào trong K8s cũng đọc được giỏ hàng)
        private List<CartItem> GetCartFromCookie()
        {
            var cartJson = Request.Cookies[CartCookieKey];
            if (string.IsNullOrEmpty(cartJson))
            {
                return new List<CartItem>();
            }

            try
            {
                return JsonSerializer.Deserialize<List<CartItem>>(cartJson) ?? new List<CartItem>();
            }
            catch
            {
                return new List<CartItem>();
            }
        }

        // Lưu giỏ hàng vào Cookie
        private void SaveCartToCookie(List<CartItem> cart)
        {
            var cartJson = JsonSerializer.Serialize(cart);
            Response.Cookies.Append(CartCookieKey, cartJson, new CookieOptions
            {
                Expires = DateTimeOffset.UtcNow.AddDays(7),
                SameSite = SameSiteMode.Lax,
                IsEssential = true
            });
        }

        // GET: /Cart
        public IActionResult Index()
        {
            var cart = GetCartFromCookie();
            return View(cart);
        }

        // POST: /Cart/AddToCart
        [HttpPost]
        public async Task<IActionResult> AddToCart(int productId, int quantity = 1, bool buyNow = false)
        {
            var product = await _context.Products.FindAsync(productId);
            if (product == null || product.Stock <= 0)
            {
                TempData["ErrorMessage"] = "Sản phẩm không tồn tại hoặc đã hết hàng!";
                return RedirectToAction("Index", "Product");
            }

            var cart = GetCartFromCookie();
            var item = cart.FirstOrDefault(c => c.ProductId == productId);

            if (item != null)
            {
                item.Quantity += quantity;
                if (item.Quantity > product.Stock)
                {
                    item.Quantity = product.Stock;
                }
            }
            else
            {
                cart.Add(new CartItem
                {
                    ProductId = product.Id,
                    ProductName = product.Name,
                    Price = product.Price,
                    Quantity = Math.Min(quantity, product.Stock),
                    ImageUrl = product.ImageUrl
                });
            }

            SaveCartToCookie(cart);
            TempData["SuccessMessage"] = $"Đã thêm \"{product.Name}\" vào giỏ hàng!";

            if (buyNow)
            {
                return RedirectToAction(nameof(Index));
            }

            return RedirectToAction("Index", "Product");
        }

        // POST: /Cart/UpdateQuantity
        [HttpPost]
        public IActionResult UpdateQuantity(int productId, int quantity)
        {
            var cart = GetCartFromCookie();
            var item = cart.FirstOrDefault(c => c.ProductId == productId);

            if (item != null)
            {
                if (quantity <= 0)
                {
                    cart.Remove(item);
                }
                else
                {
                    item.Quantity = quantity;
                }
                SaveCartToCookie(cart);
            }

            return RedirectToAction(nameof(Index));
        }

        // POST: /Cart/Remove
        [HttpPost]
        public IActionResult Remove(int productId)
        {
            var cart = GetCartFromCookie();
            var item = cart.FirstOrDefault(c => c.ProductId == productId);

            if (item != null)
            {
                cart.Remove(item);
                SaveCartToCookie(cart);
                TempData["SuccessMessage"] = $"Đã xóa \"{item.ProductName}\" khỏi giỏ hàng.";
            }

            return RedirectToAction(nameof(Index));
        }

        // POST: /Cart/Checkout (Đặt hàng và thanh toán)
        [HttpPost]
        public async Task<IActionResult> Checkout()
        {
            // Kiểm tra đăng nhập
            var userIdStr = HttpContext.Session.GetString("UserId") ?? Request.Cookies["UserId"];
            var username = HttpContext.Session.GetString("Username") ?? Request.Cookies["Username"];

            if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
            {
                TempData["ErrorMessage"] = "Vui lòng đăng nhập để tiến hành mua hàng và thanh toán!";
                return RedirectToAction("Login", "Account");
            }

            var cart = GetCartFromCookie();
            if (!cart.Any())
            {
                TempData["ErrorMessage"] = "Giỏ hàng của bạn đang trống!";
                return RedirectToAction(nameof(Index));
            }

            // Kiểm tra tồn kho trước khi trừ
            decimal totalAmount = 0;
            foreach (var item in cart)
            {
                var product = await _context.Products.FindAsync(item.ProductId);
                if (product == null)
                {
                    TempData["ErrorMessage"] = $"Sản phẩm \"{item.ProductName}\" không còn tồn tại!";
                    return RedirectToAction(nameof(Index));
                }

                if (product.Stock < item.Quantity)
                {
                    TempData["ErrorMessage"] = $"Sản phẩm \"{product.Name}\" chỉ còn {product.Stock} cái trong kho, không đủ số lượng bạn đặt!";
                    return RedirectToAction(nameof(Index));
                }

                // Trừ tồn kho trong SQL Server
                product.Stock -= item.Quantity;
                totalAmount += product.Price * item.Quantity;
            }

            // Tạo bản ghi Đơn hàng (Order) lưu vào SQL Server
            var order = new Order
            {
                UserId = userId,
                OrderDate = DateTime.Now,
                TotalAmount = totalAmount
            };

            _context.Orders.Add(order);
            await _context.SaveChangesAsync();

            // Xóa sạch giỏ hàng sau khi mua thành công
            Response.Cookies.Delete(CartCookieKey);

            return RedirectToAction(nameof(OrderSuccess), new { id = order.Id });
        }

        // GET: /Cart/OrderSuccess/5
        public async Task<IActionResult> OrderSuccess(int id)
        {
            var order = await _context.Orders
                .Include(o => o.User)
                .FirstOrDefaultAsync(o => o.Id == id);

            if (order == null)
            {
                return RedirectToAction("Index", "Product");
            }

            return View(order);
        }

        // GET: /Cart/Orders (Danh sách đơn hàng của tôi)
        public async Task<IActionResult> Orders()
        {
            var userIdStr = HttpContext.Session.GetString("UserId") ?? Request.Cookies["UserId"];
            if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int userId))
            {
                return RedirectToAction("Login", "Account");
            }

            var orders = await _context.Orders
                .Where(o => o.UserId == userId)
                .OrderByDescending(o => o.OrderDate)
                .ToListAsync();

            return View(orders);
        }
    }
}
