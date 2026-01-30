﻿using Pcm.Domain.Entities;

public class Booking
{
    public int Id { get; set; }

    public int CourtId { get; set; }
    public Court Court { get; set; } = null!;

    public int MemberId { get; set; }
    public Member Member { get; set; } = null!;

    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }

    public decimal TotalPrice { get; set; }
    public string Status { get; set; } = "Pending";
    
    public DateTime CreatedDate { get; set; } = DateTime.Now;
    public DateTime? CancelledAt { get; set; }
    public string? CancelReason { get; set; }
    
    public bool IsRecurringChild { get; set; }
    public int? RecurringId { get; set; }
}
