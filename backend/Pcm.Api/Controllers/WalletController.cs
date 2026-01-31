using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Pcm.Infrastructure.Data;
using Pcm.Domain.Entities;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class WalletController : ControllerBase
    {
        private readonly AppDbContext _context;

        public WalletController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost("deposit")]
        public async Task<IActionResult> Deposit([FromBody] DepositRequest request)
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

            if (request.Amount <= 0)
                return BadRequest("Amount must be positive");

            member.WalletBalance += request.Amount;

            var transaction = new WalletTransaction
            {
                MemberId = member.Id,
                Amount = request.Amount,
                Type = "Deposit",
                Status = "Completed",
                Description = request.Description
            };

            _context.WalletTransactions.Add(transaction);

            // Create Notification
            var notification = new Notification
            {
                MemberId = member.Id,
                Title = "Deposit Successful",
                Message = $"You have successfully deposited {request.Amount:N0} VND into your wallet.",
                Type = "Deposit",
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            };
            _context.Notifications.Add(notification);

            await _context.SaveChangesAsync();

            return Ok(new
            {
                Balance = member.WalletBalance
            });
        }

        [HttpGet("transactions")]
        public async Task<IActionResult> GetTransactions()
        {
            var memberIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(JwtRegisteredClaimNames.Sub);

            if (memberIdClaim == null)
                return Unauthorized("Invalid token");

            int memberId = int.Parse(memberIdClaim.Value);

            var transactions = await _context.WalletTransactions
                .Where(t => t.MemberId == memberId)
                .OrderByDescending(t => t.CreatedDate)
                .ToListAsync();

            return Ok(transactions);
        }

        // ADMIN: xem toàn bộ giao dịch
        [HttpGet("admin/all")]
        public async Task<IActionResult> GetAllTransactions()
        {
            var emailClaim =
                User.FindFirst(JwtRegisteredClaimNames.Email) ??
                User.FindFirst(ClaimTypes.Email);

            if (emailClaim == null || !emailClaim.Value.Equals("luc@gmail.com", StringComparison.OrdinalIgnoreCase))
                return Forbid();

            var transactions = await _context.WalletTransactions
                .OrderByDescending(t => t.CreatedDate)
                .Take(500)
                .ToListAsync();

            return Ok(transactions);
        }
    }

    public record DepositRequest(
        decimal Amount,
        string? Description
    );
}
