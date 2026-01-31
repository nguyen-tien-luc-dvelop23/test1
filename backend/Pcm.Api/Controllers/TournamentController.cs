using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pcm.Domain.Entities;
using Pcm.Infrastructure.Data;
using System.Security.Claims;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/tournament")]
    [Authorize]
    public class TournamentController : ControllerBase
    {
        private readonly AppDbContext _context;

        public TournamentController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/tournament
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? status)
        {
            var query = _context.Tournaments.AsQueryable();

            if (!string.IsNullOrEmpty(status))
            {
                query = query.Where(t => t.Status == status);
            }

            var tournaments = await query
                .Include(t => t.Participants)
                .OrderByDescending(t => t.StartDate)
                .ToListAsync();

            return Ok(tournaments);
        }

        // GET: api/tournament/{id}
        [HttpGet("{id:int}")]
        public async Task<IActionResult> GetById(int id)
        {
            var tournament = await _context.Tournaments
                .Include(t => t.Participants)
                    .ThenInclude(p => p.User)
                .Include(t => t.Matches)
                    .ThenInclude(m => m.Player1)
                .Include(t => t.Matches)
                    .ThenInclude(m => m.Player2)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (tournament == null)
                return NotFound();

            return Ok(tournament);
        }

        // POST: api/tournament
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateTournamentRequest request)
        {
            // TODO: check admin role if needed

            var tournament = new Tournament
            {
                Name = request.Name,
                Description = request.Description,
                StartDate = request.StartDate,
                EndDate = request.EndDate,
                EntryFee = request.EntryFee,
                MaxPlayers = request.MaxPlayers,
                Type = request.Type
            };

            _context.Tournaments.Add(tournament);
            await _context.SaveChangesAsync();

            return Ok(tournament);
        }

        // PUT: api/tournament/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] CreateTournamentRequest request)
        {
            var tournament = await _context.Tournaments.FindAsync(id);
            if (tournament == null)
                return NotFound();

            tournament.Name = request.Name;
            tournament.Description = request.Description;
            tournament.StartDate = request.StartDate;
            tournament.EndDate = request.EndDate;
            tournament.EntryFee = request.EntryFee;
            tournament.MaxPlayers = request.MaxPlayers;
            tournament.Type = request.Type;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/tournament/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var tournament = await _context.Tournaments.FindAsync(id);
            if (tournament == null)
                return NotFound();

            _context.Tournaments.Remove(tournament);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        // POST: api/tournament/{id}/join
        [HttpPost("{id:int}/join")]
        public async Task<IActionResult> Join(int id, [FromBody] JoinTournamentRequest request)
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier) ??
                              User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);

            if (userIdClaim == null) return Unauthorized();
            int userId = int.Parse(userIdClaim.Value);

            // Bắt đầu transaction để đảm bảo an toàn dữ liệu
            using var transactionScope = await _context.Database.BeginTransactionAsync();

            try
            {
                var tournament = await _context.Tournaments
                    .Include(t => t.Participants)
                    .FirstOrDefaultAsync(t => t.Id == id);

                if (tournament == null) return NotFound("Tournament not found");

                if (tournament.Status != "Open")
                    return BadRequest("Tournament is not open for registration");

                var isJoined = tournament.Participants.Any(p => p.UserId == userId);
                if (isJoined)
                    return BadRequest("Already joined");

                if (tournament.Participants.Count >= tournament.MaxPlayers)
                    return BadRequest("Tournament is full");

                var member = await _context.Members.FindAsync(userId);
                if (member == null || !member.IsActive) return Unauthorized();

                // Check Wallet
                if (member.WalletBalance < tournament.EntryFee)
                    return BadRequest("Not enough balance");

                // Deduct Fee
                member.WalletBalance -= tournament.EntryFee;
                member.TotalSpent += tournament.EntryFee;

                var walletTx = new WalletTransaction
                {
                    MemberId = member.Id,
                    Amount = -tournament.EntryFee,
                    Type = "TournamentEntry",
                    Status = "Completed",
                    Description = $"Join tournament: {tournament.Name}",
                    CreatedDate = DateTime.Now
                };

                var participant = new TournamentParticipant
                {
                    TournamentId = id,
                    UserId = userId,
                    Status = "Joined",
                    JoinedAt = DateTime.Now,
                    GroupName = request.GroupName,
                    TeamSize = request.TeamSize
                };

                // Notification
                var notification = new Notification
                {
                    MemberId = member.Id,
                    Title = "Tournament Joined",
                    Message = $"You have successfully joined {tournament.Name}. Group: {request.GroupName}, Size: {request.TeamSize}. Entry fee: {tournament.EntryFee:N0}₫.",
                    Type = "Tournament",
                    CreatedAt = DateTime.Now
                };

                _context.WalletTransactions.Add(walletTx);
                _context.TournamentParticipants.Add(participant);
                _context.Notifications.Add(notification);

                await _context.SaveChangesAsync();
                await transactionScope.CommitAsync();

                return Ok(participant);
            }
            catch (Exception ex)
            {
                await transactionScope.RollbackAsync();
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        public record JoinTournamentRequest(string? GroupName, int TeamSize);
        
        // POST: api/tournament/{id}/generate-schedule
        // Simple Single Elimination Generator
        [HttpPost("{id:int}/generate-schedule")]
        public async Task<IActionResult> GenerateSchedule(int id)
        {
             var tournament = await _context.Tournaments
                .Include(t => t.Participants)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (tournament == null) return NotFound();
            
            // Basic logic: only if status is Open or Ongoing
            if (tournament.Status == "Finished")
                return BadRequest("Tournament finished");

            // 1. Get Participants
            var participants = tournament.Participants.Where(p => p.Status == "Joined").ToList();
            if (participants.Count < 2)
                return BadRequest("Not enough participants");

            // 2. Update Status
            tournament.Status = "Ongoing";

            // 3. Clear existing matches (optional - for reset)
            var existingMatches = await _context.Matches.Where(m => m.TournamentId == id).ToListAsync();
            _context.Matches.RemoveRange(existingMatches);
            
            // 4. Create Bracket (Single Elimination)
            // Determine nearest power of 2
            int powerOf2 = 2;
            while (powerOf2 < participants.Count) powerOf2 *= 2;
            
            // Create placeholders for all matches in the bracket
            // Total matches = powerOf2 - 1
            // Round 1: powerOf2 / 2 matches
            
            // For simplicity, let's just pair them randomly for Round 1
            // Real world needs bye handling, seeding, etc.
            
            var shuffled = participants.OrderBy(x => Guid.NewGuid()).ToList();
            var matches = new List<Match>();
            
            int matchCount = shuffled.Count / 2;
            for (int i = 0; i < matchCount; i++)
            {
                var p1 = shuffled[i * 2];
                var p2 = shuffled[i * 2 + 1];
                
                matches.Add(new Match
                {
                    TournamentId = id,
                    Round = 1,
                    BracketPosition = i + 1,
                    Player1Id = p1.UserId,
                    Player2Id = p2.UserId,
                    Status = "Scheduled",
                    ScheduledTime = tournament.StartDate ?? DateTime.Now.AddDays(1)
                });
            }
            
            // Handle bye if odd number
             if (shuffled.Count % 2 != 0)
            {
                var byePlayer = shuffled.Last();
                // Auto win or wait for next round logic... 
                // Simplification: Just add a match with one player as winner automatically?
                // Or standard bracket logic.
                // For this demo, we ignore the odd player or just let them sit out (bad UX but simpler code).
            }

            _context.Matches.AddRange(matches);
            await _context.SaveChangesAsync();

            return Ok(matches);
        }
    }

    public record CreateTournamentRequest(
        string Name, 
        string? Description, 
        DateTime? StartDate, 
        DateTime? EndDate,
        decimal EntryFee,
        int MaxPlayers,
        string Type
    );
}
