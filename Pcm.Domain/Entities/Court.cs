namespace Pcm.Domain.Entities;

public class Court
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public string? Description { get; set; }
    public decimal PricePerHour { get; set; }
}
