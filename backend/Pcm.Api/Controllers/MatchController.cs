using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Pcm.Api.Hubs;
using Pcm.Domain.Entities;
using Pcm.Infrastructure.Data;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/match")]
    [Authorize]
    public class MatchController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IHubContext<PcmHub> _hubContext;

        public MatchController(AppDbContext context, IHubContext<PcmHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        // GET: api/match/ping
        [HttpGet("ping")]
        [AllowAnonymous]
        public IActionResult Ping() => Ok("MatchController is alive!");

        // GET: api/match/{id}
        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            var match = await _context.Matches
                .Include(m => m.Player1)
                .Include(m => m.Player2)
                .FirstOrDefaultAsync(m => m.Id == id);

            if (match == null) return NotFound();
            return Ok(match);
        }

        // POST: api/match/challenge
        [HttpPost("challenge")]
        public async Task<IActionResult> CreateChallenge([FromBody] CreateChallengeRequest request)
        {
            var userIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value 
                            ?? User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub)?.Value;

            if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int memberId)) 
                return Unauthorized("Invalid user token");
            
            var member = await _context.Members.FindAsync(memberId);
            if (member == null) return Unauthorized($"Member profile not found (ID: {memberId})");

            var match = new Match
            {
                Player1Id = member.Id,
                Player2Id = request.OpponentId,
                ScheduledTime = request.ScheduledTime,
                Status = request.OpponentId == null ? "Open" : "Pending", // Open if no opponent, Pending if directed
                TournamentId = null, // Standalone match
                Round = 0,
                BracketPosition = 0
            };

            _context.Matches.Add(match);
            await _context.SaveChangesAsync();

            return Ok(match);
        }

        // GET: api/match/challenges
        [HttpGet("challenges")]
        public async Task<IActionResult> GetChallenges()
        {
            var matches = await _context.Matches
                .Include(m => m.Player1)
                .Include(m => m.Player2)
                .Where(m => m.TournamentId == null && (m.Status == "Open" || m.Status == "Pending" || m.Status == "Scheduled"))
                .OrderByDescending(m => m.CreatedAt)
                .ToListAsync();

            return Ok(matches);
        }
        
        // POST: api/match/{id}/accept
        [HttpPost("{id:int}/accept")]
        public async Task<IActionResult> AcceptChallenge(int id)
        {
            var userIdStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value 
                            ?? User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub)?.Value;

            if (string.IsNullOrEmpty(userIdStr) || !int.TryParse(userIdStr, out int memberId)) 
                return Unauthorized("Invalid user token");
            
            var member = await _context.Members.FindAsync(memberId);
            if (member == null) return Unauthorized($"Member profile not found (ID: {memberId})");

            var match = await _context.Matches.FindAsync(id);
            if (match == null) return NotFound();
            
            if (match.Status != "Open" && match.Status != "Pending")
                return BadRequest("Match is not open for acceptance");

            if (match.Player2Id != null && match.Player2Id != member.Id)
                return BadRequest("This challenge is not for you");
            
            if (match.Player1Id == member.Id)
                return BadRequest("Cannot accept your own challenge");

            match.Player2Id = member.Id;
            match.Status = "Scheduled";
            match.UpdatedAt = DateTime.Now;
            
            await _context.SaveChangesAsync();
            return Ok(match);
        }
    }
    
    public record UpdateMatchResultRequest(string ScorePlayer1, string ScorePlayer2, int WinnerId);
    public record CreateChallengeRequest(int? OpponentId, DateTime ScheduledTime);
}
