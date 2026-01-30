using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Pcm.Domain.Entities;
using Pcm.Domain.Enums;
using Pcm.Infrastructure.Data;

public static class SeedData
{
    public static async Task SeedUserAsync(IServiceProvider services)
    {
        var userManager = services.GetRequiredService<UserManager<IdentityUser>>();
        var db = services.GetRequiredService<AppDbContext>();

        // Identity admin (bonus)
        var email = "admin@pcm.com";
        var password = "123456";

        var user = await userManager.FindByEmailAsync(email);
        if (user == null)
        {
            user = new IdentityUser
            {
                UserName = email,
                Email = email,
                EmailConfirmed = true
            };

            await userManager.CreateAsync(user, password);
        }

        // Member admin theo yêu cầu chấm bài (AuthController dùng bảng Members)
        var memberAdminEmail = "luc@gmail.com";
        var memberAdminPassword = "123456";

        var member = await db.Members.FirstOrDefaultAsync(m => m.Email == memberAdminEmail);
        if (member == null)
        {
            db.Members.Add(new Member
            {
                Email = memberAdminEmail,
                Password = memberAdminPassword,
                FullName = "Nguyễn Tiến Lực",
                IsActive = true,
                WalletBalance = 5000000,
                TotalSpent = 0,
                Tier = Tier.Diamond
            });
            await db.SaveChangesAsync();
        }
        else if (member.FullName == "LUC" || member.FullName == "Nguyễn Văn A")
        {
            member.FullName = "Nguyễn Tiến Lực";
            await db.SaveChangesAsync();
        }
    }
}
