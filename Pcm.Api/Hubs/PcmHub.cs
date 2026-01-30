using Microsoft.AspNetCore.SignalR;
using System.Collections.Concurrent;

namespace Pcm.Api.Hubs
{
    [Microsoft.AspNetCore.Authorization.Authorize]
    public class PcmHub : Hub
    {
        // Lưu map giữa UserId và ConnectionId nếu cần (tuy nhiên SignalR có User Identifier provider mặc định)
        // Ở đây dùng phương pháp đơn giản: Client join group theo UserId của mình
        
        public override async Task OnConnectedAsync()
        {
            // Lấy UserId từ Claims
            var userId = Context.UserIdentifier;
            if (!string.IsNullOrEmpty(userId))
            {
                // Join group riêng cho user để gửi noti cá nhân
                await Groups.AddToGroupAsync(Context.ConnectionId, $"User_{userId}");
            }
            
            await base.OnConnectedAsync();
        }

        // Method cho client gọi lên để join group trận đấu (Match)
        public async Task JoinMatchGroup(int matchId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"Match_{matchId}");
        }

        public async Task LeaveMatchGroup(int matchId)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Match_{matchId}");
        }
    }
}
