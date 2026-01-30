using Pcm.Domain.Enums;

namespace Pcm.Domain.Entities
{
    public class Challenge
    {
        public int Id { get; set; }

        // Challenger (người thách đấu)
        public int ChallengerId { get; set; }
        public Member Challenger { get; set; } = null!;

        // Opponent (người bị thách đấu)
        public int OpponentId { get; set; }
        public Member Opponent { get; set; } = null!;

        // Challenge details
        public ChallengeType Type { get; set; } = ChallengeType.Friendly;
        public ChallengeStatus Status { get; set; } = ChallengeStatus.Pending;

        // Wager amount (only for Wager type)
        public decimal? WagerAmount { get; set; }

        // Optional message from challenger
        public string? Message { get; set; }

        // Match results (set when completed)
        public int? ChallengerScore { get; set; }
        public int? OpponentScore { get; set; }

        // Winner
        public int? WinnerId { get; set; }
        public Member? Winner { get; set; }

        // Optional booking link (if they booked a court for this match)
        public int? BookingId { get; set; }
        public Booking? Booking { get; set; }

        // Timestamps
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? AcceptedAt { get; set; }
        public DateTime? CompletedAt { get; set; }
        public DateTime? ExpiresAt { get; set; } // Challenge expires if not accepted

        // Rejected/Cancelled timestamp
        public DateTime? ResolvedAt { get; set; }
    }
}
