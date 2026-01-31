using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Pcm.Domain.Entities;
using Pcm.Domain.Enums;
using Pcm.Infrastructure.Data;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public AuthController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Password) ||
                string.IsNullOrWhiteSpace(request.FullName))
            {
                return BadRequest("Email, password và họ tên là bắt buộc.");
            }

            var emailExists = await _context.Members
                .AnyAsync(m => m.Email == request.Email);

            if (emailExists)
            {
                return BadRequest("Email đã tồn tại.");
            }

            var member = new Member
            {
                Email = request.Email.Trim(),
                Password = request.Password, // plain-text theo đề bài
                FullName = request.FullName.Trim(),
                IsActive = true,
                WalletBalance = 0,
                TotalSpent = 0,
                Tier = Tier.Standard
            };

            _context.Members.Add(member);
            await _context.SaveChangesAsync();

            var token = GenerateJwtToken(member);

            return Ok(new
            {
                Token = token,
                MemberId = member.Id,
                member.FullName,
                member.Email
            });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var member = await _context.Members.FirstOrDefaultAsync(
                x => x.Email == request.Email
                     && x.Password == request.Password
                     && x.IsActive
            );

            if (member == null)
                return Unauthorized("Invalid email or password");

            var token = GenerateJwtToken(member);
            return Ok(new { token });
        }

        [HttpGet("me")]
        public async Task<IActionResult> Me()
        {
            var memberIdClaim =
                User.FindFirst(ClaimTypes.NameIdentifier) ??
                User.FindFirst(JwtRegisteredClaimNames.Sub);

            if (memberIdClaim == null)
                return Unauthorized("Invalid token");

            int memberId = int.Parse(memberIdClaim.Value);

            var member = await _context.Members.FirstOrDefaultAsync(x => x.Id == memberId && x.IsActive);
            if (member == null)
                return Unauthorized("Member not active");

            var walletBalance = member.WalletBalance;

            return Ok(new
            {
                member.Id,
                member.FullName,
                member.Email,
                member.AvatarUrl,
                member.Tier,
                WalletBalance = walletBalance
            });
        }

        private string GenerateJwtToken(Member member)
        {
            var jwt = _configuration.GetSection("Jwt");
            var key = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwt["Key"]!)
            );

            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, member.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Email, member.Email),
                new Claim("fullName", member.FullName)
            };

            if (member.Email == "luc@gmail.com" || member.Email.ToLower().Contains("admin"))
            {
                claims.Add(new Claim(ClaimTypes.Role, "Admin"));
            }

            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: jwt["Issuer"],
                audience: jwt["Audience"],
                claims: claims,
                expires: DateTime.Now.AddMinutes(
                    int.Parse(jwt["ExpireMinutes"]!)
                ),
                signingCredentials: creds
            );

            return new JwtSecurityTokenHandler().WriteToken(token);
        }
    }

    public record LoginRequest(string Email, string Password);
    public record RegisterRequest(string Email, string Password, string FullName);
}
