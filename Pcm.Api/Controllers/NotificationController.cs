using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Pcm.Api.Hubs;
using Pcm.Domain.Entities;
using Pcm.Infrastructure.Data;
using System.Security.Claims;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificationController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IHubContext<PcmHub> _hubContext;

        public NotificationController(AppDbContext context, IHubContext<PcmHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        [HttpGet]
        public async Task<IActionResult> GetNotifications([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
        {
            var userIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

            if (userIdClaim == null) return Unauthorized("Invalid token");

            var userId = int.Parse(userIdClaim.Value);

            var query = _context.Notifications
                .Where(n => n.MemberId == userId)
                .OrderByDescending(n => n.CreatedAt);

            var total = await query.CountAsync();
            var items = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var unreadCount = await _context.Notifications
                .Where(n => n.MemberId == userId && !n.IsRead)
                .CountAsync();

            return Ok(new
            {
                Total = total,
                UnreadCount = unreadCount,
                Page = page,
                PageSize = pageSize,
                Items = items
            });
        }

        [HttpPost("{id:int}/read")]
        public async Task<IActionResult> MarkAsRead(int id)
        {
            var userIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

            if (userIdClaim == null) return Unauthorized("Invalid token");

            var userId = int.Parse(userIdClaim.Value);
            var noti = await _context.Notifications.FirstOrDefaultAsync(n => n.Id == id && n.MemberId == userId);

            if (noti == null) return NotFound();

            if (!noti.IsRead)
            {
                noti.IsRead = true;
                await _context.SaveChangesAsync();
            }

            return Ok(noti);
        }

        [HttpPost("read-all")]
        public async Task<IActionResult> MarkAllAsRead()
        {
            var userIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

            if (userIdClaim == null) return Unauthorized("Invalid token");

            var userId = int.Parse(userIdClaim.Value);
            
            var unreadNotis = await _context.Notifications
                .Where(n => n.MemberId == userId && !n.IsRead)
                .ToListAsync();

            if (unreadNotis.Any())
            {
                foreach (var n in unreadNotis)
                {
                    n.IsRead = true;
                }
                await _context.SaveChangesAsync();
            }

            return Ok(new { message = "All marked as read" });
        }

        // Test API để giả lập gửi thông báo (Admin dùng)
        [HttpPost("send-test")]
        public async Task<IActionResult> SendTestNotification([FromBody] SendNotificationRequest request)
        {
            // Lưu DB
            var noti = new Notification
            {
                MemberId = request.MemberId,
                Title = request.Title,
                Message = request.Message,
                Type = "System",
                IsRead = false,
                CreatedAt = DateTime.Now
            };

            _context.Notifications.Add(noti);
            await _context.SaveChangesAsync();

            // Gửi SignalR realtime
            // Client join group "User_{userId}"
            await _hubContext.Clients.Group($"User_{request.MemberId}")
                .SendAsync("ReceiveNotification", new
                {
                    Id = noti.Id,
                    Title = noti.Title,
                    Message = noti.Message,
                    Type = noti.Type,
                    CreatedAt = noti.CreatedAt
                });

            return Ok(noti);
        }
    }

    public record SendNotificationRequest(int MemberId, string Title, string Message);
}
