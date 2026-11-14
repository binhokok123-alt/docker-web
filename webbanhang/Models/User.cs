using System.ComponentModel.DataAnnotations;

namespace webbanhang.Models
{
    public class User
    {
        public int Id { get; set; }

        [Required, MaxLength(100)]
        public string Username { get; set; } = string.Empty;

        [Required, EmailAddress, MaxLength(200)]
        public string Email { get; set; } = string.Empty;

        [Required]
        public string Password { get; set; } = string.Empty;

        // Navigation property: 1 User -> nhiều Order
        public ICollection<Order> Orders { get; set; } = new List<Order>();
    }
}
