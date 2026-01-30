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
    [Route("api/[controller]")]
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

        // POST: api/match/{id}/result
        [HttpPost("{id:int}/result")]
        public async Task<IActionResult> UpdateResult(int id, [FromBody] UpdateMatchResultRequest request)
        {
            var match = await _context.Matches.FindAsync(id);
            if (match == null) return NotFound();

            // Check permissions (only Referee or Admin?)
            // For now, allow logged in users for demo simplicity

            match.ScorePlayer1 = request.ScorePlayer1;
            match.ScorePlayer2 = request.ScorePlayer2;
            match.WinnerId = request.WinnerId;
            match.Status = "Finished";
            match.UpdatedAt = DateTime.Now;

            // TODO: Advance bracket logic (find next match, set player1 or player2 slot)
            // if (match.NextMatchId != null) { ... }

            await _context.SaveChangesAsync();

            // SignalR Broadcast
            await _hubContext.Clients.All.SendAsync("UpdateMatchScore", new
            {
                MatchId = match.Id,
                ScorePlayer1 = match.ScorePlayer1,
                ScorePlayer2 = match.ScorePlayer2,
                WinnerId = match.WinnerId,
                Status = match.Status
            });
            
            // Also notify specific group if used
            await _hubContext.Clients.Group($"Match_{match.Id}").SendAsync("MatchUpdate", match);

            return Ok(match);
        }
    }

    public record UpdateMatchResultRequest(string ScorePlayer1, string ScorePlayer2, int WinnerId);
}
