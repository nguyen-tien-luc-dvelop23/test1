using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pcm.Infrastructure.Data;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize] // Should be [Authorize(Roles = "Admin")]
    public class DashboardController : ControllerBase
    {
        private readonly AppDbContext _context;

        public DashboardController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("admin/stats")]
        public async Task<IActionResult> GetAdminStats()
        {
            // Doanh thu (Nạp/Chi) theo tháng hiện tại
            var now = DateTime.Now;
            var startOfMonth = new DateTime(now.Year, now.Month, 1);
            var endOfMonth = startOfMonth.AddMonths(1);

            // Tổng booking trong tháng
            var bookingCount = await _context.Bookings
                .Where(b => b.CreatedDate >= startOfMonth && b.CreatedDate < endOfMonth) // Note: Booking entity uses CreatedAt or similar? Need to check.
                .CountAsync();

            // Tổng nạp tiền (Deposit)
            var totalDeposit = await _context.WalletTransactions
                .Where(t => t.Type == "Deposit" && t.CreatedDate >= startOfMonth && t.CreatedDate < endOfMonth)
                .SumAsync(t => t.Amount);
            
            // Tổng chi (BookingPayment, TournamentEntry) - Amount is negative
            var totalSpent = await _context.WalletTransactions
                .Where(t => (t.Type == "BookingPayment" || t.Type == "TournamentEntry") && t.CreatedDate >= startOfMonth && t.CreatedDate < endOfMonth)
                .SumAsync(t => t.Amount);

            // Doanh thu chart data (theo ngày trong tháng)
            var dailyRevenue = await _context.WalletTransactions
                .Where(t => t.Type == "Deposit" && t.CreatedDate >= startOfMonth && t.CreatedDate < endOfMonth)
                .GroupBy(t => t.CreatedDate.Date)
                .Select(g => new { Date = g.Key, Total = g.Sum(x => x.Amount) })
                .OrderBy(x => x.Date)
                .ToListAsync();

            return Ok(new
            {
                Month = now.Month,
                Year = now.Year,
                BookingCount = bookingCount,
                TotalDeposit = totalDeposit,
                TotalSpent = Math.Abs(totalSpent), // convert to positive for display
                DailyRevenue = dailyRevenue
            });
        }
    }
}
