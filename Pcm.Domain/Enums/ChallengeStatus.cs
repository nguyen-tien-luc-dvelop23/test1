namespace Pcm.Domain.Enums
{
    public enum ChallengeStatus
    {
        Pending = 0,      // Challenge created, waiting for opponent response
        Accepted = 1,     // Opponent accepted, match can be played
        Rejected = 2,     // Opponent declined
        Completed = 3,    // Match finished with results
        Cancelled = 4     // Creator cancelled before acceptance
    }
}
