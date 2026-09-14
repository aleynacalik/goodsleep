using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LittleDreams.Api.Data;
using System.Security.Claims;
using System;
using System.ComponentModel.DataAnnotations;

namespace LittleDreams.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Tüm endpoint'ler token gerektirir
    public class FamilyController : ControllerBase
    {
        private readonly AppDbContext _context;

        public FamilyController(AppDbContext context)
        {
            _context = context;
        }

        // Giriş yapan kullanıcının veritabanındaki FamilyId'sini döndürür (JWT claim'i stale olabilir)
        private async Task<string?> GetCallerFamilyIdAsync()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!Guid.TryParse(userId, out var userGuid)) return null;
            var user = await _context.Users.FindAsync(userGuid);
            return user?.FamilyId;
        }

        // 1. Aile ve üye bilgilerini getir
        [HttpGet("{id}")]
        public async Task<IActionResult> GetFamily(string id)
        {
            if (await GetCallerFamilyIdAsync() != id) return Forbid();

            var family = await _context.Families.FindAsync(id);
            if (family == null) return NotFound();

            var members = await _context.Users
                .Where(u => u.FamilyId == id)
                .Select(u => u.Name ?? "İsimsiz Üye")
                .ToListAsync();

            return Ok(new
            {
                family.Id,
                family.FamilyName,
                family.BabyName,
                family.BabyBirthDate,
                members
            });
        }

        // 2. Aile (ve bebek) bilgilerini güncelle
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateFamily(string id, [FromBody] UpdateFamilyDto request)
        {
            if (await GetCallerFamilyIdAsync() != id) return Forbid();

            var family = await _context.Families.FindAsync(id);
            if (family == null) return NotFound();

            family.FamilyName = request.FamilyName;
            family.BabyName = request.BabyName;
            family.BabyBirthDate = request.BabyBirthDate;

            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "Aile bilgisi güncellenemedi."); }
            return Ok(family);
        }

        // 3. Davet Kodu Üret (güvenli rastgele sayı üreteci FamilyController'da da kullanılıyor)
        [HttpPost("{id}/invite")]
        public async Task<IActionResult> GenerateInvite(string id)
        {
            if (await GetCallerFamilyIdAsync() != id) return Forbid();

            var family = await _context.Families.FindAsync(id);
            if (family == null) return NotFound();

            var bytes = new byte[4];
            System.Security.Cryptography.RandomNumberGenerator.Fill(bytes);
            var number = Math.Abs(BitConverter.ToInt32(bytes, 0));
            family.InviteCode = (number % 900000 + 100000).ToString();
            family.InviteCodeExpires = DateTime.UtcNow.AddHours(24);

            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "Davet kodu oluşturulamadı."); }
            return Ok(new { code = family.InviteCode });
        }

        // 4. Koç İlerlemesini Getir
        [HttpGet("{id}/coach-progress")]
        public async Task<IActionResult> GetCoachProgress(string id)
        {
            if (await GetCallerFamilyIdAsync() != id) return Forbid();

            var family = await _context.Families.FindAsync(id);
            if (family == null) return NotFound();
            if (string.IsNullOrEmpty(family.CoachProgress))
                return Ok(new { });
            return Content(family.CoachProgress, "application/json");
        }

        // 5. Koç İlerlemesini Kaydet
        [HttpPut("{id}/coach-progress")]
        public async Task<IActionResult> SaveCoachProgress(string id, [FromBody] System.Text.Json.JsonElement data)
        {
            if (await GetCallerFamilyIdAsync() != id) return Forbid();

            var family = await _context.Families.FindAsync(id);
            if (family == null) return NotFound();
            family.CoachProgress = data.GetRawText();
            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "İlerleme kaydedilemedi."); }
            return NoContent();
        }

        // 6. Aileye Katıl
        [HttpPost("join")]
        [Microsoft.AspNetCore.RateLimiting.EnableRateLimiting("login")]
        public async Task<IActionResult> JoinFamily([FromBody] JoinRequest request)
        {
            var family = await _context.Families.FirstOrDefaultAsync(f => f.InviteCode == request.Code);
            if (family == null || family.InviteCodeExpires < DateTime.UtcNow)
                return BadRequest("Geçersiz veya süresi dolmuş kod.");

            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userId) || !Guid.TryParse(userId, out var userGuid))
                return Unauthorized("Kullanıcı kimliği bulunamadı.");

            var user = await _context.Users.FindAsync(userGuid);
            if (user == null) return BadRequest("Kullanıcı bulunamadı.");

            user.FamilyId = family.Id;
            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "Aileye katılım kaydedilemedi."); }

            return Ok(new { familyId = family.Id });
        }
    }

    // --- DTO Sınıfları ---
    public class UpdateFamilyDto
    {
        [System.ComponentModel.DataAnnotations.StringLength(100)]
        public string FamilyName { get; set; } = string.Empty;

        [System.ComponentModel.DataAnnotations.StringLength(100)]
        public string BabyName { get; set; } = string.Empty;

        public DateTime? BabyBirthDate { get; set; }
    }

    public class JoinRequest
    {
        [Required]
        [StringLength(6, MinimumLength = 6)]
        public string Code { get; set; } = string.Empty;
    }
}
