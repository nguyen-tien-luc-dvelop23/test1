using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Pcm.Domain.Entities;

public class Tournament
{
    public int Id { get; set; }
    
    [Required]
    [MaxLength(150)]
    public string Name { get; set; } = string.Empty;
    
    public string? Description { get; set; }
    
    // Open, Ongoing, Finished
    public string Status { get; set; } = "Open"; 
    
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    
    [Column(TypeName = "decimal(18,2)")]
    public decimal EntryFee { get; set; }
    
    public int MaxPlayers { get; set; }
    
    // SingleElimination, RoundRobin, etc.
    public string Type { get; set; } = "SingleElimination"; 
    
    public DateTime CreatedAt { get; set; } = DateTime.Now;

    public ICollection<TournamentParticipant> Participants { get; set; } = new List<TournamentParticipant>();
    public ICollection<Match> Matches { get; set; } = new List<Match>();
}
