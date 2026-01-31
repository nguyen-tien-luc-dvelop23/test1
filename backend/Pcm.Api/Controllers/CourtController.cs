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

        // POST: api/court
        [HttpPost]
        public async Task<IActionResult> Create([FromBody] Court court)
        {
            if (court == null)
                return BadRequest("Court data is required");

            _context.Courts.Add(court);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetAll), new { id = court.Id }, court);
        }

        // PUT: api/court/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] Court court)
        {
            var existing = await _context.Courts.FindAsync(id);
            if (existing == null)
                return NotFound();

            existing.Name = court.Name;
            existing.Description = court.Description;
            existing.PricePerHour = court.PricePerHour;

            await _context.SaveChangesAsync();
            return NoContent();
        }

        // DELETE: api/court/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var court = await _context.Courts.FindAsync(id);
            if (court == null)
                return NotFound();

            _context.Courts.Remove(court);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}
