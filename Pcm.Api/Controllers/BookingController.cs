using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using Pcm.Infrastructure.Data;
using Pcm.Domain.Entities;
using Pcm.Api.Services;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class BookingController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly NotificationService _notificationService;

        public BookingController(AppDbContext context, NotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        [HttpPost]
        public async Task<IActionResult> CreateBooking([FromBody] CreateBookingRequest request)
        {
            var memberIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(JwtRegisteredClaimNames.Sub);

            if (memberIdClaim == null)
                return Unauthorized("Invalid token");

            int memberId = int.Parse(memberIdClaim.Value);

            var member = await _context.Members.FindAsync(memberId);
            if (member == null || !member.IsActive)
                return Unauthorized("Member not active");

            var court = await _context.Courts.FindAsync(request.CourtId);
            if (court == null)
                return BadRequest("Court not found");

            var hours = (request.EndTime - request.StartTime).TotalHours;
            if (hours <= 0)
                return BadRequest("Invalid time range");

            var totalPrice = (decimal)hours * court.PricePerHour;

            if (member.WalletBalance < totalPrice)
                return BadRequest("Not enough balance");

            member.WalletBalance -= totalPrice;
            member.TotalSpent += totalPrice;

            var booking = new Booking
            {
                MemberId = member.Id,
                CourtId = court.Id,
                StartTime = request.StartTime,
                EndTime = request.EndTime,
                TotalPrice = totalPrice,
                Status = "Confirmed"
            };

            _context.Bookings.Add(booking);

            var walletTransaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -totalPrice,
                Type = "BookingPayment",
                Status = "Completed",
                Description = "Booking payment"
            };

            _context.WalletTransactions.Add(walletTransaction);

            var notification = _notificationService.Create(
                member.Id,
                "Booking đã xác nhận",
                $"{court.Name} • {request.StartTime:HH:mm} - {request.EndTime:HH:mm}",
                "Booking"
            );

            await _context.SaveChangesAsync();
            await _notificationService.PushAsync(notification);

            return Ok(booking);
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var bookings = await _context.Bookings
                .Include(b => b.Court)
                .Include(b => b.Member)
                .ToListAsync();

            return Ok(bookings);
        }

        [HttpGet("my-bookings")]
        public async Task<IActionResult> GetMyBookings()
        {
            var memberIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(JwtRegisteredClaimNames.Sub);

            if (memberIdClaim == null)
                return Unauthorized("Invalid token");

            int memberId = int.Parse(memberIdClaim.Value);

            var bookings = await _context.Bookings
                .Include(b => b.Court)
                .Where(b => b.MemberId == memberId)
                .OrderByDescending(b => b.CreatedDate)
                .ToListAsync();

            return Ok(bookings);
        }

        [HttpGet("calendar")]
        public async Task<IActionResult> GetCalendar([FromQuery] DateTime from, [FromQuery] DateTime to)
        {
            if (to <= from)
                return BadRequest("Invalid range");

            var bookings = await _context.Bookings
                .Include(b => b.Court)
                .Include(b => b.Member)
                .Where(b => b.StartTime < to && b.EndTime > from)
                .ToListAsync();

            return Ok(bookings);
        }

        [HttpPost("recurring")]
        public async Task<IActionResult> CreateRecurringBooking([FromBody] CreateRecurringBookingRequest request)
        {
            var memberIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(JwtRegisteredClaimNames.Sub);

            if (memberIdClaim == null)
                return Unauthorized("Invalid token");

            int memberId = int.Parse(memberIdClaim.Value);

            var member = await _context.Members.FindAsync(memberId);
            if (member == null || !member.IsActive)
                return Unauthorized("Member not active");

            var court = await _context.Courts.FindAsync(request.CourtId);
            if (court == null)
                return BadRequest("Court not found");

            var dates = new List<DateTime>();
            var current = request.FromDate.Date;
            while (current <= request.ToDate.Date)
            {
                if (request.DaysOfWeek.Contains((int)current.DayOfWeek))
                {
                    dates.Add(current);
                }

                current = current.AddDays(1);
            }

            if (dates.Count == 0)
                return BadRequest("No dates generated");

            var bookings = new List<Booking>();
            decimal totalPrice = 0;

            foreach (var date in dates)
            {
                var start = date.Date.Add(request.StartTime);
                var end = date.Date.Add(request.EndTime);

                var hours = (end - start).TotalHours;
                if (hours <= 0)
                    continue;

                var price = (decimal)hours * court.PricePerHour;
                totalPrice += price;

                var booking = new Booking
                {
                    MemberId = member.Id,
                    CourtId = court.Id,
                    StartTime = start,
                    EndTime = end,
                    TotalPrice = price,
                    Status = "Confirmed"
                };

                bookings.Add(booking);
            }

            if (bookings.Count == 0)
                return BadRequest("No valid bookings");

            if (member.WalletBalance < totalPrice)
                return BadRequest("Not enough balance");

            member.WalletBalance -= totalPrice;
            member.TotalSpent += totalPrice;

            _context.Bookings.AddRange(bookings);

            var walletTransaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = -totalPrice,
                Type = "BookingRecurringPayment",
                Status = "Completed",
                Description = "Recurring bookings payment"
            };

            _context.WalletTransactions.Add(walletTransaction);

            var notification = _notificationService.Create(
                member.Id,
                "Đặt lịch định kỳ thành công",
                $"Đã tạo {bookings.Count} lượt đặt • Tổng tiền: {totalPrice:N0}₫",
                "Booking"
            );

            await _context.SaveChangesAsync();
            await _notificationService.PushAsync(notification);

            return Ok(bookings);
        }

        [HttpPost("cancel/{id:int}")]
        public async Task<IActionResult> Cancel(int id)
        {
            var memberIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(JwtRegisteredClaimNames.Sub);

            if (memberIdClaim == null)
                return Unauthorized("Invalid token");

            int memberId = int.Parse(memberIdClaim.Value);

            var booking = await _context.Bookings
                .Include(b => b.Member)
                .Include(b => b.Court)
                .FirstOrDefaultAsync(b => b.Id == id);

            if (booking == null)
                return NotFound();

            if (booking.MemberId != memberId)
                return Forbid();

            if (booking.Status != "Confirmed")
                return BadRequest("Booking cannot be cancelled");

            var now = DateTime.UtcNow;
            var hoursBefore = (booking.StartTime - now).TotalHours;

            decimal refundRate = 0;
            if (hoursBefore >= 24)
                refundRate = 1m;
            else if (hoursBefore >= 12)
                refundRate = 0.5m;

            booking.Status = "Cancelled";

            decimal refundAmount = 0;
            if (refundRate > 0)
            {
                refundAmount = booking.TotalPrice * refundRate;

                var member = await _context.Members.FindAsync(memberId);
                if (member != null)
                {
                    member.WalletBalance += refundAmount;

                    var walletTransaction = new WalletTransaction
                    {
                        MemberId = member.Id,
                        Amount = refundAmount,
                        Type = "BookingRefund",
                        Status = "Completed",
                        Description = "Booking refund"
                    };

                    _context.WalletTransactions.Add(walletTransaction);
                }
            }

            var notiTitle = refundAmount > 0 ? "Hủy booking và hoàn tiền" : "Hủy booking thành công";
            var notiMessage = refundAmount > 0
                ? $"{booking.Court?.Name ?? "Sân"} • Đã hoàn {refundAmount:N0}₫ vào ví."
                : $"{booking.Court?.Name ?? "Sân"} • Không đủ điều kiện hoàn tiền.";

            var notification = _notificationService.Create(
                memberId,
                notiTitle,
                notiMessage,
                "Booking"
            );

            await _context.SaveChangesAsync();
            await _notificationService.PushAsync(notification);

            return Ok(booking);
        }
    }

    public record CreateBookingRequest(
        int CourtId,
        DateTime StartTime,
        DateTime EndTime
    );

    public record CreateRecurringBookingRequest(
        int CourtId,
        DateTime FromDate,
        DateTime ToDate,
        TimeSpan StartTime,
        TimeSpan EndTime,
        List<int> DaysOfWeek
    );
}
