using Microsoft.AspNetCore.SignalR;
using Pcm.Api.Hubs;
using Pcm.Domain.Entities;
using Pcm.Infrastructure.Data;

namespace Pcm.Api.Services;

public sealed class NotificationService
{
    private readonly AppDbContext _context;
    private readonly IHubContext<PcmHub> _hubContext;

    public NotificationService(AppDbContext context, IHubContext<PcmHub> hubContext)
    {
        _context = context;
        _hubContext = hubContext;
    }

    public Notification Create(int memberId, string title, string message, string type)
    {
        var noti = new Notification
        {
            MemberId = memberId,
            Title = title,
            Message = message,
            Type = type,
            IsRead = false,
            CreatedAt = DateTime.UtcNow
        };

        _context.Notifications.Add(noti);
        return noti;
    }

    public async Task<Notification> CreateAndSaveAsync(int memberId, string title, string message, string type)
    {
        var noti = Create(memberId, title, message, type);
        await _context.SaveChangesAsync();
        return noti;
    }

    public Task PushAsync(Notification noti)
    {
        return _hubContext.Clients.Group($"User_{noti.MemberId}")
            .SendAsync("ReceiveNotification", new
            {
                noti.Id,
                noti.Title,
                noti.Message,
                noti.Type,
                noti.IsRead,
                noti.CreatedAt
            });
    }
}

