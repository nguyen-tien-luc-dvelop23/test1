using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Configuration;
using Pcm.Infrastructure.Data;
using Pcm.Domain.Entities;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/diagnostics")]
    [AllowAnonymous]
    public class DiagnosticsController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public DiagnosticsController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        [HttpGet]
        public async Task<IActionResult> GetDiagnostics()
        {
            var result = new Dictionary<string, object>();

            // 1. Server Time
            result["ServerTime"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss");
            result["Environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Unknown";

            // 2. Database Connection Check
            try
            {
                var canConnect = await _context.Database.CanConnectAsync();
                result["DatabaseConnection"] = canConnect ? "OK" : "FAILED";
            }
            catch (Exception ex)
            {
                result["DatabaseConnection"] = $"ERROR: {ex.Message}";
            }

            // 3. Admin User Check (luc@gmail.com)
            try
            {
                var adminUser = await _context.Members.FirstOrDefaultAsync(m => m.Email == "luc@gmail.com");
                if (adminUser != null)
                {
                    result["AdminUserFound"] = true;
                    result["AdminUserId"] = adminUser.Id;
                    result["AdminUserName"] = adminUser.FullName;
                    result["AdminUserIsAdmin"] = adminUser.IsAdmin; // KEY CHECK
                }
                else
                {
                    result["AdminUserFound"] = false;
                }
            }
            catch (Exception ex)
            {
                result["AdminUserCheck"] = $"ERROR: {ex.Message}";
            }

            // 4. Migration Check (Basic) - Check if IsAdmin column exists essentially by the query above succeeding
            // If the query above failed with "column not found", it means migration didn't run.

            return Ok(result);
        }
    }
}
