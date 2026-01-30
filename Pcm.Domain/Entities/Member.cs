using Pcm.Domain.Enums;

namespace Pcm.Domain.Entities
{
    public class Member
    {
        public int Id { get; set; }

        // 🔥 TÀI KHOẢN ĐĂNG NHẬP
        public string Email { get; set; } = string.Empty;

        // 🔥 MẬT KHẨU (PLAIN TEXT – THEO YÊU CẦU)
        public string Password { get; set; } = string.Empty;

        public string FullName { get; set; } = string.Empty;

        public bool IsActive { get; set; }

        // ===== CÁC FIELD KHÁC (GIỮ NGUYÊN) =====
        public decimal WalletBalance { get; set; }
        public Tier Tier { get; set; }
        public decimal TotalSpent { get; set; }

        public string? PhoneNumber { get; set; }
        public string? Address { get; set; }
        public string? AvatarUrl { get; set; }
    }
}
