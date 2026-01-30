namespace Pcm.Domain.Entities;

public class WalletTransaction
{
    public int Id { get; set; }
    public int MemberId { get; set; }

    public decimal Amount { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Status { get; set; } = "Pending";

    public string? Description { get; set; }
    public DateTime CreatedDate { get; set; } = DateTime.Now;
}
