using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using LittleDreams.Api.Data;
using LittleDreams.Api.Models;
using ClosedXML.Excel;
using System.Security.Claims;
using System;
using System.Linq;
using System.IO;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace LittleDreams.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Tüm endpoint'ler token gerektirir
    public class SleepLogsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public SleepLogsController(AppDbContext context)
        {
            _context = context;
        }

        // Giriş yapan kullanıcının veritabanındaki FamilyId'sini döndürür
        private async Task<string?> GetCallerFamilyIdAsync()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!Guid.TryParse(userId, out var userGuid)) return null;
            var user = await _context.Users.FindAsync(userGuid);
            return user?.FamilyId;
        }

        // 1. GET: api/SleepLogs/family/{familyId}?limit=200&offset=0
        [HttpGet("family/{familyId}")]
        public async Task<ActionResult<IEnumerable<SleepLog>>> GetSleepLogs(
            string familyId, [FromQuery] int limit = 200, [FromQuery] int offset = 0)
        {
            if (await GetCallerFamilyIdAsync() != familyId) return Forbid();

            limit = Math.Clamp(limit, 1, 500);
            offset = Math.Max(0, offset);

            var logs = await _context.SleepLogs
                .Where(s => s.FamilyId == familyId)
                .OrderByDescending(s => s.StartTime)
                .Skip(offset)
                .Take(limit)
                .ToListAsync();

            return Ok(logs);
        }

        // 2. POST: api/SleepLogs
        [HttpPost]
        public async Task<ActionResult<SleepLog>> PostSleepLog([FromBody] SleepLog sleepLog)
        {
            var callerFamilyId = await GetCallerFamilyIdAsync();
            if (callerFamilyId == null || callerFamilyId != sleepLog.FamilyId) return Forbid();

            if (sleepLog.DurationInSeconds <= 0 || sleepLog.EndTime <= sleepLog.StartTime)
                return BadRequest("Geçersiz uyku kaydı.");

            if (sleepLog.StartTime > DateTime.UtcNow.AddMinutes(5))
                return BadRequest("Başlangıç zamanı gelecekte olamaz.");

            if (sleepLog.EndTime - sleepLog.StartTime > TimeSpan.FromHours(24))
                return BadRequest("Uyku süresi 24 saatten fazla olamaz.");

            // Client'tan gelen Id ve tarih alanlarını yok say — sunucuda üret
            sleepLog.Id = Guid.NewGuid();

            _context.SleepLogs.Add(sleepLog);
            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "Kayıt kaydedilemedi."); }

            return Ok(sleepLog);
        }

        // 3. DELETE: api/SleepLogs/{id}
        [HttpDelete("{id}")]
        public async Task<IActionResult> DeleteSleepLog(Guid id)
        {
            var sleepLog = await _context.SleepLogs.FindAsync(id);
            if (sleepLog == null) return NotFound();

            if (await GetCallerFamilyIdAsync() != sleepLog.FamilyId) return Forbid();

            _context.SleepLogs.Remove(sleepLog);
            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "Kayıt silinemedi."); }

            return NoContent();
        }

        // 4. GET: api/SleepLogs/export/{familyId}
        [HttpGet("export/{familyId}")]
        public async Task<IActionResult> ExportToExcel(string familyId)
        {
            if (await GetCallerFamilyIdAsync() != familyId) return Forbid();

            var logs = await _context.SleepLogs
                .Where(s => s.FamilyId == familyId)
                .OrderBy(s => s.StartTime)
                .ToListAsync();

            if (!logs.Any())
                return NotFound("Dışa aktarılacak uyku kaydı bulunamadı.");

            using (var workbook = new XLWorkbook())
            {
                var worksheet = workbook.Worksheets.Add("Sleep Log Raporu");

                worksheet.Cell(1, 1).Value = "Tarih";
                worksheet.Cell(1, 2).Value = "Uyuma Saati";
                worksheet.Cell(1, 3).Value = "Uyanma Saati";
                worksheet.Cell(1, 4).Value = "Süre";

                var headerRow = worksheet.Range("A1:D1");
                headerRow.Style.Font.Bold = true;
                headerRow.Style.Fill.BackgroundColor = XLColor.Lavender;
                headerRow.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;

                int currentRow = 2;
                foreach (var log in logs)
                {
                    var duration = TimeSpan.FromSeconds(log.DurationInSeconds);
                    var durationText = duration.Hours > 0
                        ? $"{duration.Hours}s {duration.Minutes}dk"
                        : $"{duration.Minutes}dk";

                    worksheet.Cell(currentRow, 1).Value = log.StartTime.ToLocalTime().ToString("dd/MM/yyyy");
                    worksheet.Cell(currentRow, 2).Value = log.StartTime.ToLocalTime().ToString("HH:mm");
                    worksheet.Cell(currentRow, 3).Value = log.EndTime.ToLocalTime().ToString("HH:mm");
                    worksheet.Cell(currentRow, 4).Value = durationText;
                    currentRow++;
                }

                worksheet.Columns().AdjustToContents();

                using (var stream = new MemoryStream())
                {
                    workbook.SaveAs(stream);
                    var content = stream.ToArray();
                    var fileName = $"LittleDreams_Rapor_{DateTime.Now:ddMMyyyy}.xlsx";
                    return File(content,
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                        fileName);
                }
            }
        }

        // 5. PUT: api/SleepLogs/{id}
        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateSleepLog(Guid id, [FromBody] UpdateSleepLogDto request)
        {
            var sleepLog = await _context.SleepLogs.FindAsync(id);
            if (sleepLog == null) return NotFound("Kayıt bulunamadı.");

            if (await GetCallerFamilyIdAsync() != sleepLog.FamilyId) return Forbid();

            if (request.EndTime <= request.StartTime || request.DurationInSeconds <= 0)
                return BadRequest("Geçersiz uyku kaydı.");

            sleepLog.StartTime = request.StartTime;
            sleepLog.EndTime = request.EndTime;
            sleepLog.DurationInSeconds = request.DurationInSeconds;

            try { await _context.SaveChangesAsync(); }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            { return StatusCode(500, "Kayıt güncellenemedi."); }

            return Ok(sleepLog);
        }
    }

    public class UpdateSleepLogDto
    {
        [Required]
        public DateTime StartTime { get; set; }

        [Required]
        public DateTime EndTime { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "Süre 0'dan büyük olmalıdır.")]
        public int DurationInSeconds { get; set; }
    }
}
