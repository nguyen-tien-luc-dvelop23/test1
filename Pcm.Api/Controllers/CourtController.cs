using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pcm.Infrastructure.Data;
using Pcm.Domain.Entities;

namespace Pcm.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class CourtController : ControllerBase
    {
        private readonly AppDbContext _context;

        public CourtController(AppDbContext context)
        {
            _context = context;
        }

        // GET: api/court
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var courts = await _context.Courts.ToListAsync();
            return Ok(courts);
        }
    }
}
