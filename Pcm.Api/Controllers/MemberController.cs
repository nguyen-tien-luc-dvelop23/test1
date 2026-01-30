using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pcm.Domain.Enums;
using Pcm.Infrastructure.Data;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class MemberController : ControllerBase
    {
        private readonly AppDbContext _context;

        public MemberController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetMembers(
            [FromQuery] string? search,
            [FromQuery] string? tier,
            [FromQuery] bool includeInactive = false,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20
        )
        {
            if (page <= 0)
                page = 1;
            if (pageSize <= 0 || pageSize > 100)
                pageSize = 20;

            var query = _context.Members.AsQueryable();

            if (!includeInactive)
            {
                query = query.Where(m => m.IsActive);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                query = query.Where(m => m.FullName.Contains(search) || m.Email.Contains(search));
            }

            if (!string.IsNullOrWhiteSpace(tier) && Enum.TryParse<Tier>(tier, true, out var parsedTier))
            {
                query = query.Where(m => m.Tier == parsedTier);
            }

            var total = await query.CountAsync();

            var items = await query
                .OrderBy(m => m.FullName)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(m => new MemberListItemDto(
                    m.Id,
                    m.FullName,
                    m.Email,
                    m.AvatarUrl,
                    m.Tier,
                    RankFrom(m.TotalSpent)
                ))
                .ToListAsync();

            return Ok(new
            {
                total,
                page,
                pageSize,
                items
            });
        }

        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetMember(int id)
        {
            var member = await _context.Members
                .Where(m => m.Id == id)
                .Select(m => new MemberDetailDto(
                    m.Id,
                    m.FullName,
                    m.Email,
                    m.PhoneNumber,
                    m.Address,
                    m.AvatarUrl,
                    m.Tier,
                    m.WalletBalance,
                    m.TotalSpent,
                    RankFrom(m.TotalSpent),
                    m.IsActive
                ))
                .FirstOrDefaultAsync();

            if (member == null) return NotFound();
            return Ok(member);
        }

        [HttpGet("{id:int}/profile")]
        public async Task<IActionResult> GetProfile(int id)
        {
            var member = await _context.Members
                .Where(m => m.Id == id && m.IsActive)
                .Select(m => new MemberDetailDto(
                    m.Id,
                    m.FullName,
                    m.Email,
                    m.PhoneNumber,
                    m.Address,
                    m.AvatarUrl,
                    m.Tier,
                    m.WalletBalance,
                    m.TotalSpent,
                    RankFrom(m.TotalSpent),
                    m.IsActive
                ))
                .FirstOrDefaultAsync();

            if (member == null)
                return NotFound();

            var recentBookings = await _context.Bookings
                .Include(b => b.Court)
                .Where(b => b.MemberId == id)
                .OrderByDescending(b => b.StartTime)
                .Take(10)
                .ToListAsync();

            return Ok(new
            {
                member,
                recentBookings
            });
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> UpdateProfile(int id, [FromBody] UpdateProfileRequest request)
        {
            var member = await _context.Members.FindAsync(id);
            if (member == null) return NotFound();

            // Chỉ cho phép update nếu là chính mình hoặc admin (logic check quyền đơn giản là check ID trong JWT)
            // Ở đây tạm bỏ qua check role admin, chỉ check id trùng
            var memberIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ??
                                User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

            if (memberIdClaim != null && int.Parse(memberIdClaim.Value) != id)
            {
                return Forbid();
            }

            member.FullName = request.FullName ?? member.FullName;
            member.PhoneNumber = request.PhoneNumber ?? member.PhoneNumber;
            member.Address = request.Address ?? member.Address;
            member.AvatarUrl = request.AvatarUrl ?? member.AvatarUrl;
            
            // Không update password ở đây

            await _context.SaveChangesAsync();
            return Ok(new MemberDetailDto(
                member.Id,
                member.FullName,
                member.Email,
                member.PhoneNumber,
                member.Address,
                member.AvatarUrl,
                member.Tier,
                member.WalletBalance,
                member.TotalSpent,
                RankFrom(member.TotalSpent),
                member.IsActive
            ));
        }

        [HttpPost("{id:int}/change-password")]
        public async Task<IActionResult> ChangePassword(int id, [FromBody] ChangePasswordRequest request)
        {
            var member = await _context.Members.FindAsync(id);
            if (member == null) return NotFound();

            var memberIdClaim = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier) ??
                                User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

            if (memberIdClaim != null && int.Parse(memberIdClaim.Value) != id)
            {
                return Forbid();
            }

            // Logic đơn giản so sánh plain text theo yêu cầu đề bài
            if (member.Password != request.OldPassword)
            {
                return BadRequest("Incorrect old password");
            }

            member.Password = request.NewPassword;
            await _context.SaveChangesAsync();

            return Ok(new { message = "Password changed successfully" });
        }

        private static double RankFrom(decimal totalSpent)
        {
            if (totalSpent <= 0) return 0;
            return Math.Round((double)(totalSpent / 1_000_000m), 2);
        }
    }

    public record UpdateProfileRequest(string? FullName, string? PhoneNumber, string? Address, string? AvatarUrl);
    public record ChangePasswordRequest(string OldPassword, string NewPassword);

    public record MemberListItemDto(
        int Id,
        string FullName,
        string Email,
        string? AvatarUrl,
        Tier Tier,
        double Rank
    );

    public record MemberDetailDto(
        int Id,
        string FullName,
        string Email,
        string? PhoneNumber,
        string? Address,
        string? AvatarUrl,
        Tier Tier,
        decimal WalletBalance,
        decimal TotalSpent,
        double Rank,
        bool IsActive
    );
}
