using System.ComponentModel.DataAnnotations.Schema;

namespace Pcm.Domain.Entities;

public class Match
{
    public int Id { get; set; }
    
    public int TournamentId { get; set; }
    public Tournament Tournament { get; set; } = null!;
    
    public int Round { get; set; }
    public int BracketPosition { get; set; }
    
    public int? Player1Id { get; set; }
    public Member? Player1 { get; set; }
    
    public int? Player2Id { get; set; }
    public Member? Player2 { get; set; }
    
    // e.g., "11-9,7-11,11-8"
    public string? ScorePlayer1 { get; set; }
    public string? ScorePlayer2 { get; set; }
    
    public int? WinnerId { get; set; }
    public Member? Winner { get; set; }
    
    public DateTime? ScheduledTime { get; set; }
    
    // Scheduled, InProgress, Finished
    public string Status { get; set; } = "Scheduled"; 
    
    public int? NextMatchId { get; set; }
    public Match? NextMatch { get; set; }
    
    public DateTime CreatedAt { get; set; } = DateTime.Now;
    public DateTime? UpdatedAt { get; set; }
}
