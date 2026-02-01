using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Pcm.Infrastructure.Data;
using Pcm.Infrastructure;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// =======================
// SERVICES
// =======================

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });
builder.Services.AddSignalR();

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// DbContext - MySQL
builder.Services.AddDbContext<AppDbContext>(options =>
{
    options.UseMySql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        new MySqlServerVersion(new Version(8, 0, 31))
    );
});

// Identity
builder.Services.AddIdentity<IdentityUser, IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

// JWT
var jwtSettings = builder.Configuration.GetSection("Jwt");
var key = Encoding.UTF8.GetBytes(jwtSettings["Key"]!);

// IMPORTANT:
// AddIdentity đăng ký cookie auth. Nếu để cookie làm default challenge => API sẽ redirect /Account/Login (thường thành 404).
// Vì đây là Web API cho Flutter, ta set default auth/challenge = JWT Bearer.
builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    })
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSettings["Issuer"],
            ValidAudience = jwtSettings["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(key)
        };
    });

// Đảm bảo không redirect cookie khi unauthorized (tránh 404 cho API clients)
builder.Services.ConfigureApplicationCookie(options =>
{
    options.Events.OnRedirectToLogin = ctx =>
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        return Task.CompletedTask;
    };
    options.Events.OnRedirectToAccessDenied = ctx =>
    {
        ctx.Response.StatusCode = StatusCodes.Status403Forbidden;
        return Task.CompletedTask;
    };
});

// Authorization (cần để [Authorize] hoạt động đúng)
builder.Services.AddAuthorization();

// CORS (CHO FLUTTER)
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader());
});

// Configure lowercase URLs
builder.Services.Configure<RouteOptions>(options => 
{
    options.LowercaseUrls = true;
    options.LowercaseQueryStrings = true;
});

var app = builder.Build();

// =======================
// MIDDLEWARE
// =======================

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
try 
{
    using (var scope = app.Services.CreateScope())
    {
        try {
            var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            
            // Ensure database is up to date (Migration)
            try {
                await context.Database.MigrateAsync();
            } catch (Exception ex) {
                Console.WriteLine($"Migration failed: {ex.Message}");
            }

            try {
                await SeedData.SeedUserAsync(scope.ServiceProvider);
                await DbSeeder.SeedAsync(context);
            } catch (Exception ex) {
                Console.WriteLine($"Seeding failed: {ex.Message}");
            }
        } catch (Exception ex) {
            Console.WriteLine($"Critical Error in DbContext initialization: {ex.Message}");
        }
    }
}
catch (Exception ex)
{
    Console.WriteLine($"Fatal Startup Error: {ex.Message}");
}

// Flutter Web/Chrome thường gọi qua http://localhost:<port>
// Nếu bật redirect HTTPS mà không có https endpoint => client sẽ lỗi "connection refused".
// if (!app.Environment.IsDevelopment())
// {
//     app.UseHttpsRedirection();
// }

// ⚠️ THỨ TỰ ĐÚNG

// GLOBAL PING (Bypass everything)
app.MapGet("/", () => "PCM Server is running!"); 
app.MapGet("/ping", () => "pong");
app.MapGet("/api/ping", () => "pong-api");

app.UseCors("AllowAll");

// ⚠️ THỨ TỰ ĐÚNG
app.UseAuthentication();
app.UseAuthorization();

// Minimal API Ping - Always Works
app.MapGet("/api/version", () => new { Version = "1.0.29", LastUpdated = DateTime.Now.ToString(), Status = "Active" });
app.MapHub<Pcm.Api.Hubs.PcmHub>("/pcmHub");

app.Run();
