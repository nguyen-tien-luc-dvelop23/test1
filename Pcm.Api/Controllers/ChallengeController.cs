using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Pcm.Api.Hubs;
using Pcm.Domain.Entities;
using Pcm.Domain.Enums;
using Pcm.Infrastructure.Data;
using System.Security.Claims;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ChallengeController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IHubContext<PcmHub> _hubContext;

        public ChallengeController(AppDbContext context, IHubContext<PcmHub> hubContext)
        {
            _context = context;
            _hubContext = hubContext;
        }

        private int GetCurrentUserId()
        {
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier) ??
                              User.FindFirst(System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Sub);
            return int.Parse(userIdClaim!.Value);
        }

        // POST: api/challenge
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] CreateChallengeRequest request)
        {
            var userId = GetCurrentUserId();

            // Validate opponent exists
            if (request.OpponentId == userId)
                return BadRequest("Cannot challenge yourself");

            var opponent = await _context.Members.FindAsync(request.OpponentId);
            if (opponent == null || !opponent.IsActive)
                return BadRequest("Opponent not found or inactive");

            var challenger = await _context.Members.FindAsync(userId);
            if (challenger == null || !challenger.IsActive)
                return Unauthorized();

            // For wager challenges, check wallet balance
            if (request.Type == "Wager")
            {
                if (!request.WagerAmount.HasValue || request.WagerAmount.Value <= 0)
                    return BadRequest("Wager amount must be greater than 0");

                if (challenger.WalletBalance < request.WagerAmount.Value)
                    return BadRequest("Insufficient wallet balance");

                if (opponent.WalletBalance < request.WagerAmount.Value)
                    return BadRequest("Opponent has insufficient wallet balance");
            }

            var challenge = new Challenge
            {
                ChallengerId = userId,
                OpponentId = request.OpponentId,
                Type = request.Type == "Wager" ? ChallengeType.Wager : ChallengeType.Friendly,
                Status = ChallengeStatus.Pending,
                WagerAmount = request.WagerAmount,
                Message = request.Message,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddHours(24) // Challenge expires in 24 hours
            };

            _context.Challenges.Add(challenge);

            // Create notification for opponent
            var notification = new Notification
            {
                MemberId = request.OpponentId,
                Title = "New Challenge",
                Message = $"{challenger.FullName} has challenged you to a {(challenge.Type == ChallengeType.Wager ? $"wager match ({request.WagerAmount:N0}₫)" : "friendly match")}!",
                Type = "Challenge",
                CreatedAt = DateTime.UtcNow,
                IsRead = false
            };
            _context.Notifications.Add(notification);

            await _context.SaveChangesAsync();

            // SignalR notification
            await _hubContext.Clients.User(request.OpponentId.ToString())
                .SendAsync("NewChallenge", new
                {
                    ChallengeId = challenge.Id,
                    ChallengerId = userId,
                    ChallengerName = challenger.FullName,
                    Type = challenge.Type.ToString(),
                    WagerAmount = challenge.WagerAmount,
                    Message = challenge.Message
                });

            return Ok(challenge);
        }

        // GET: api/challenge/my-challenges
        [HttpGet("my-challenges")]
        public async Task<IActionResult> GetMyChallenges()
        {
            var userId = GetCurrentUserId();

            var challenges = await _context.Challenges
                .Include(c => c.Challenger)
                .Include(c => c.Opponent)
                .Include(c => c.Winner)
                .Where(c => c.ChallengerId == userId || c.OpponentId == userId)
                .OrderByDescending(c => c.CreatedAt)
                .ToListAsync();

            return Ok(challenges);
        }

        // GET: api/challenge/pending
        [HttpGet("pending")]
        public async Task<IActionResult> GetPending()
        {
            var userId = GetCurrentUserId();

            var challenges = await _context.Challenges
                .Include(c => c.Challenger)
                .Include(c => c.Opponent)
                .Where(c => c.OpponentId == userId && c.Status == ChallengeStatus.Pending)
                .OrderByDescending(c => c.CreatedAt)
                .ToListAsync();

            return Ok(challenges);
        }

        // POST: api/challenge/{id}/accept
        [HttpPost("{id:int}/accept")]
        public async Task<IActionResult> Accept(int id)
        {
            var userId = GetCurrentUserId();

            using var transaction = await _context.Database.BeginTransactionAsync();

            try
            {
                var challenge = await _context.Challenges
                    .Include(c => c.Challenger)
                    .Include(c => c.Opponent)
                    .FirstOrDefaultAsync(c => c.Id == id);

                if (challenge == null)
                    return NotFound();

                if (challenge.OpponentId != userId)
                    return Forbid("You are not the opponent of this challenge");

                if (challenge.Status != ChallengeStatus.Pending)
                    return BadRequest("Challenge is not pending");

                // Check expiration
                if (challenge.ExpiresAt.HasValue && challenge.ExpiresAt.Value < DateTime.UtcNow)
                {
                    challenge.Status = ChallengeStatus.Cancelled;
                    challenge.ResolvedAt = DateTime.UtcNow;
                    await _context.SaveChangesAsync();
                    return BadRequest("Challenge has expired");
                }

                // For wager challenges, deduct entry fee from both wallets
                if (challenge.Type == ChallengeType.Wager && challenge.WagerAmount.HasValue)
                {
                    var challenger = challenge.Challenger;
                    var opponent = challenge.Opponent;

                    if (challenger.WalletBalance < challenge.WagerAmount.Value)
                        return BadRequest("Challenger has insufficient balance");

                    if (opponent.WalletBalance < challenge.WagerAmount.Value)
                        return BadRequest("You have insufficient wallet balance");

                    // Deduct from both
                    challenger.WalletBalance -= challenge.WagerAmount.Value;
                    opponent.WalletBalance -= challenge.WagerAmount.Value;

                    // Create transactions
                    _context.WalletTransactions.Add(new WalletTransaction
                    {
                        MemberId = challenger.Id,
                        Amount = -challenge.WagerAmount.Value,
                        Type = "ChallengeWager",
                        Status = "Completed",
                        Description = $"Wager for challenge #{id}",
                        CreatedDate = DateTime.UtcNow
                    });

                    _context.WalletTransactions.Add(new WalletTransaction
                    {
                        MemberId = opponent.Id,
                        Amount = -challenge.WagerAmount.Value,
                        Type = "ChallengeWager",
                        Status = "Completed",
                        Description = $"Wager for challenge #{id}",
                        CreatedDate = DateTime.UtcNow
                    });
                }

                challenge.Status = ChallengeStatus.Accepted;
                challenge.AcceptedAt = DateTime.UtcNow;

                // Notify challenger
                _context.Notifications.Add(new Notification
                {
                    MemberId = challenge.ChallengerId,
                    Title = "Challenge Accepted",
                    Message = $"{challenge.Opponent.FullName} has accepted your challenge!",
                    Type = "Challenge",
                    CreatedAt = DateTime.UtcNow,
                    IsRead = false
                });

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                // SignalR notification
                await _hubContext.Clients.User(challenge.ChallengerId.ToString())
                    .SendAsync("ChallengeAccepted", new
                    {
                        ChallengeId = id,
                        OpponentName = challenge.Opponent.FullName
                    });

                return Ok(challenge);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }

        // POST: api/challenge/{id}/reject
        [HttpPost("{id:int}/reject")]
        public async Task<IActionResult> Reject(int id)
        {
            var userId = GetCurrentUserId();

            var challenge = await _context.Challenges
                .Include(c => c.Challenger)
                .Include(c => c.Opponent)
                .FirstOrDefaultAsync(c => c.Id == id);

            if (challenge == null)
                return NotFound();

            if (challenge.OpponentId != userId)
                return Forbid("You are not the opponent of this challenge");

            if (challenge.Status != ChallengeStatus.Pending)
                return BadRequest("Challenge is not pending");

            challenge.Status = ChallengeStatus.Rejected;
            challenge.ResolvedAt = DateTime.UtcNow;

            // Notify challenger
            _context.Notifications.Add(new Notification
            {
                MemberId = challenge.ChallengerId,
                Title = "Challenge Rejected",
                Message = $"{challenge.Opponent.FullName} has rejected your challenge.",
                Type = "Challenge",
                CreatedAt = DateTime.UtcNow,
                IsRead = false
            });

            await _context.SaveChangesAsync();

            // SignalR notification
            await _hubContext.Clients.User(challenge.ChallengerId.ToString())
                .SendAsync("ChallengeRejected", new
                {
                    ChallengeId = id,
                    OpponentName = challenge.Opponent.FullName
                });

            return Ok(challenge);
        }

        // POST: api/challenge/{id}/cancel
        [HttpPost("{id:int}/cancel")]
        public async Task<IActionResult> Cancel(int id)
        {
            var userId = GetCurrentUserId();

            var challenge = await _context.Challenges.FindAsync(id);
            if (challenge == null)
                return NotFound();

            if (challenge.ChallengerId != userId)
                return Forbid("You are not the creator of this challenge");

            if (challenge.Status != ChallengeStatus.Pending)
                return BadRequest("Only pending challenges can be cancelled");

            challenge.Status = ChallengeStatus.Cancelled;
            challenge.ResolvedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return Ok(challenge);
        }

        // POST: api/challenge/{id}/complete
        [HttpPost("{id:int}/complete")]
        public async Task<IActionResult> Complete(int id, [FromBody] CompleteChallengeRequest request)
        {
            var userId = GetCurrentUserId();

            using var transaction = await _context.Database.BeginTransactionAsync();

            try
            {
                var challenge = await _context.Challenges
                    .Include(c => c.Challenger)
                    .Include(c => c.Opponent)
                    .FirstOrDefaultAsync(c => c.Id == id);

                if (challenge == null)
                    return NotFound();

                // Only challenger or opponent can complete
                if (challenge.ChallengerId != userId && challenge.OpponentId != userId)
                    return Forbid("You are not part of this challenge");

                if (challenge.Status != ChallengeStatus.Accepted)
                    return BadRequest("Challenge must be accepted before completion");

                // Determine winner based on scores
                int winnerId;
                if (request.ChallengerScore > request.OpponentScore)
                    winnerId = challenge.ChallengerId;
                else if (request.OpponentScore > request.ChallengerScore)
                    winnerId = challenge.OpponentId;
                else
                    return BadRequest("Scores cannot be equal");

                challenge.ChallengerScore = request.ChallengerScore;
                challenge.OpponentScore = request.OpponentScore;
                challenge.WinnerId = winnerId;
                challenge.Status = ChallengeStatus.Completed;
                challenge.CompletedAt = DateTime.UtcNow;

                // For wager challenges, transfer pot to winner
                if (challenge.Type == ChallengeType.Wager && challenge.WagerAmount.HasValue)
                {
                    var winner = winnerId == challenge.ChallengerId ? challenge.Challenger : challenge.Opponent;
                    var totalPot = challenge.WagerAmount.Value * 2;

                    winner.WalletBalance += totalPot;

                    _context.WalletTransactions.Add(new WalletTransaction
                    {
                        MemberId = winner.Id,
                        Amount = totalPot,
                        Type = "ChallengeWin",
                        Status = "Completed",
                        Description = $"Won wager challenge #{id}",
                        CreatedDate = DateTime.UtcNow
                    });
                }

                // Notify both players
                var winnerName = winnerId == challenge.ChallengerId ? challenge.Challenger.FullName : challenge.Opponent.FullName;

                _context.Notifications.Add(new Notification
                {
                    MemberId = challenge.ChallengerId,
                    Title = "Challenge Completed",
                    Message = $"Challenge completed! Winner: {winnerName}. Score: {request.ChallengerScore} - {request.OpponentScore}",
                    Type = "Challenge",
                    CreatedAt = DateTime.UtcNow,
                    IsRead = false
                });

                _context.Notifications.Add(new Notification
                {
                    MemberId = challenge.OpponentId,
                    Title = "Challenge Completed",
                    Message = $"Challenge completed! Winner: {winnerName}. Score: {request.ChallengerScore} - {request.OpponentScore}",
                    Type = "Challenge",
                    CreatedAt = DateTime.UtcNow,
                    IsRead = false
                });

                await _context.SaveChangesAsync();
                await transaction.CommitAsync();

                // SignalR notifications
                await _hubContext.Clients.Users(new[] { challenge.ChallengerId.ToString(), challenge.OpponentId.ToString() })
                    .SendAsync("ChallengeCompleted", new
                    {
                        ChallengeId = id,
                        WinnerName = winnerName,
                        ChallengerScore = request.ChallengerScore,
                        OpponentScore = request.OpponentScore
                    });

                return Ok(challenge);
            }
            catch (Exception ex)
            {
                await transaction.RollbackAsync();
                return StatusCode(500, $"Internal server error: {ex.Message}");
            }
        }
    }

    public record CreateChallengeRequest(
        int OpponentId,
        string Type, // "Friendly" or "Wager"
        decimal? WagerAmount,
        string? Message
    );

    public record CompleteChallengeRequest(
        int ChallengerScore,
        int OpponentScore
    );
}
