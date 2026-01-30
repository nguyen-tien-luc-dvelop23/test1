using System.ComponentModel.DataAnnotations.Schema;

namespace Pcm.Domain.Entities;

public class TournamentParticipant
{
    public int Id { get; set; }
    
    public int TournamentId { get; set; }
    public Tournament Tournament { get; set; } = null!;
    
    public int UserId { get; set; }
    public Member User { get; set; } = null!;
    
    public DateTime JoinedAt { get; set; } = DateTime.Now;
    
    // Joined, Withdrawn, Disqualified
    public string Status { get; set; } = "Joined";

    public string? GroupName { get; set; }
    public int TeamSize { get; set; } = 1;
}
