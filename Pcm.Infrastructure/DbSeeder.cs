using Pcm.Domain.Entities;
using Pcm.Infrastructure.Data;

namespace Pcm.Infrastructure;

public static class DbSeeder
{
    public static async Task SeedAsync(AppDbContext context)
    {
        // Seed Courts if empty
        if (!context.Courts.Any())
        {
            var courts = new List<Court>
            {
                new Court { Name = "Sân 1", Description = "Sân trong nhà, máy lạnh", PricePerHour = 100000, IsActive = true },
                new Court { Name = "Sân 2", Description = "Sân trong nhà, máy lạnh", PricePerHour = 100000, IsActive = true },
                new Court { Name = "Sân 3", Description = "Sân ngoài trời, có mái che", PricePerHour = 80000, IsActive = true },
                new Court { Name = "Sân 4", Description = "Sân ngoài trời, có mái che", PricePerHour = 80000, IsActive = true },
                new Court { Name = "Sân VIP", Description = "Sân cao cấp, đầy đủ tiện nghi", PricePerHour = 200000, IsActive = true },
            };
            context.Courts.AddRange(courts);
            await context.SaveChangesAsync();
        }

        var tournamentList = new List<Tournament>
        {
            new Tournament
            {
                Name = "Giải Pickleball Mở Rộng Toàn Quốc",
                Description = "Giải đấu quy mô lớn nhất năm với sự tham gia của các vận động viên từ khắp cả nước.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(15),
                EndDate = DateTime.Now.AddDays(20),
                EntryFee = 500000,
                MaxPlayers = 64,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Cup Giao Lưu Hội Nhóm",
                Description = "Sân chơi kết nối các câu lạc bộ pickleball trong khu vực.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(7),
                EndDate = DateTime.Now.AddDays(8),
                EntryFee = 100000,
                MaxPlayers = 16,
                Type = "RoundRobin",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Giải Vô Địch Trẻ 2026",
                Description = "Tìm kiếm tài năng trẻ cho bộ môn pickleball.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(25),
                EndDate = DateTime.Now.AddDays(27),
                EntryFee = 50000,
                MaxPlayers = 32,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Tournament Lão Tướng",
                Description = "Giải đấu dành riêng cho lứa tuổi trên 45, tinh thần thể thao cao thượng.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(10),
                EndDate = DateTime.Now.AddDays(11),
                EntryFee = 150000,
                MaxPlayers = 16,
                Type = "RoundRobin",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Siêu Cup Pickleball Miền Nam",
                Description = "Quy tụ các anh tài miền Nam tranh tài đỉnh cao.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(30),
                EndDate = DateTime.Now.AddDays(35),
                EntryFee = 300000,
                MaxPlayers = 24,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Giải Pickleball Doanh Nhân",
                Description = "Sân chơi dành cho các doanh nhân, mở rộng mạng lưới quan hệ.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(12),
                EndDate = DateTime.Now.AddDays(13),
                EntryFee = 1000000,
                MaxPlayers = 16,
                Type = "RoundRobin",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Cup Pickleball Sinh Viên",
                Description = "Giải đấu sôi động dành cho các bạn sinh viên.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(40),
                EndDate = DateTime.Now.AddDays(42),
                EntryFee = 30000,
                MaxPlayers = 48,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Giải Đôi Nam Nữ Kết Hợp",
                Description = "Thi đấu đôi nam nữ, đề cao sự phối hợp ăn ý.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(18),
                EndDate = DateTime.Now.AddDays(19),
                EntryFee = 120000,
                MaxPlayers = 20,
                Type = "RoundRobin",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Pickleball Night League",
                Description = "Giải đấu buổi tối dưới ánh đèn rực rỡ.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(5),
                EndDate = DateTime.Now.AddDays(10),
                EntryFee = 80000,
                MaxPlayers = 12,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Winter Cup 2026",
                Description = "Giải đấu mùa đông sôi động với nhiều phần quà hấp dẫn.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(45),
                EndDate = DateTime.Now.AddDays(50),
                EntryFee = 200000,
                MaxPlayers = 32,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Giải Pickleball Chuyên Nghiệp VPL",
                Description = "Hệ thống giải đấu chuyên nghiệp Việt Nam Pickleball League.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(60),
                EndDate = DateTime.Now.AddDays(70),
                EntryFee = 2000000,
                MaxPlayers = 128,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Weekend Warriors Challenge",
                Description = "Giải đấu cuối tuần dành cho những ‘chiến binh’ phong trào.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(3),
                EndDate = DateTime.Now.AddDays(4),
                EntryFee = 70000,
                MaxPlayers = 16,
                Type = "RoundRobin",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Mixed Doubles Master",
                Description = "Tìm kiếm bậc thầy phối hợp trong nội dung đôi nam nữ.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(22),
                EndDate = DateTime.Now.AddDays(23),
                EntryFee = 150000,
                MaxPlayers = 24,
                Type = "RoundRobin",
                CreatedAt = DateTime.Now
            },
            new Tournament
            {
                Name = "Giải Pickleball Từ Thiện",
                Description = "Thi đấu vì cộng đồng, toàn bộ phí tham gia dành cho quỹ bảo trợ trẻ em.",
                Status = "Open",
                StartDate = DateTime.Now.AddDays(14),
                EndDate = DateTime.Now.AddDays(14),
                EntryFee = 100000,
                MaxPlayers = 32,
                Type = "SingleElimination",
                CreatedAt = DateTime.Now
            }
        };

        foreach (var t in tournamentList)
        {
            if (!context.Tournaments.Any(existing => existing.Name == t.Name))
            {
                context.Tournaments.Add(t);
            }
        }
        
        await context.SaveChangesAsync();
    }
}
