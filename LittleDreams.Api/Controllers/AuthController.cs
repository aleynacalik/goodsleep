using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.ComponentModel.DataAnnotations;
using LittleDreams.Api.Data;
using LittleDreams.Api.Models;
using Microsoft.AspNetCore.RateLimiting;

namespace LittleDreams.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public AuthController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        // 1. KAYIT OL
        [HttpPost("register")]
        [EnableRateLimiting("login")]
        public async Task<IActionResult> Register([FromBody] RegisterDto request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            if (await _context.Users.AnyAsync(u => u.Email == request.Email))
                return Conflict("Bu e-posta adresi zaten kullanılıyor.");

            var newFamily = new Family();
            _context.Families.Add(newFamily);

            var user = new User
            {
                Name = request.Name,
                Email = request.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password, workFactor: 12),
                FamilyId = newFamily.Id
            };

            _context.Users.Add(user);
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException)
            {
                return Conflict("Bu e-posta adresi zaten kullanılıyor.");
            }

            return Ok(new { message = "Kayıt başarılı!" });
        }

        // 2. GİRİŞ YAP (rate limiting: 5 deneme / 15 dakika)
        [HttpPost("login")]
        [EnableRateLimiting("login")]
        public async Task<IActionResult> Login([FromBody] LoginDto request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == request.Email);
            // Timing attack koruması: kullanıcı bulunamasa da her zaman BCrypt çalıştır
            const string dummyHash = "$2a$12$dummy.hash.prevents.timing.attack.from.user.enumeration";
            var passwordValid = BCrypt.Net.BCrypt.Verify(request.Password, user?.PasswordHash ?? dummyHash);
            if (user == null || !passwordValid)
                return Unauthorized("E-posta veya şifre hatalı.");

            var token = BuildToken(user);
            return Ok(new
            {
                token,
                user = new { user.Id, user.Name, user.Email, user.FamilyId }
            });
        }

        // 3. HESAP SİL
        [HttpDelete("account")]
        [Microsoft.AspNetCore.Authorization.Authorize]
        [EnableRateLimiting("login")]
        public async Task<IActionResult> DeleteAccount([FromBody] DeleteAccountDto request)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (!Guid.TryParse(userId, out var userGuid)) return Unauthorized();

            var user = await _context.Users.FindAsync(userGuid);
            if (user == null) return NotFound();

            if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
                return Unauthorized("Şifre hatalı.");

            var familyId = user.FamilyId;
            _context.Users.Remove(user);
            await _context.SaveChangesAsync();

            // Ailede başka üye kalmadıysa aileyi ve tüm uyku kayıtlarını sil
            var remainingMembers = await _context.Users.AnyAsync(u => u.FamilyId == familyId);
            if (!remainingMembers)
            {
                var family = await _context.Families.FindAsync(familyId);
                if (family != null) _context.Families.Remove(family);
                try { await _context.SaveChangesAsync(); }
                catch (Microsoft.EntityFrameworkCore.DbUpdateException) { /* cascade zaten temizler */ }
            }

            return NoContent();
        }

        // 4. TOKEN YENİLE
        [HttpPost("refresh")]
        public IActionResult Refresh()
        {
            var authHeader = Request.Headers["Authorization"].FirstOrDefault();
            if (authHeader == null || !authHeader.StartsWith("Bearer "))
                return Unauthorized();

            var oldToken = authHeader["Bearer ".Length..].Trim();
            var key = Encoding.ASCII.GetBytes(
                Environment.GetEnvironmentVariable("JWT_SECRET")
                ?? _configuration["JwtSettings:SecretKey"]!);

            var tokenHandler = new JwtSecurityTokenHandler();
            ClaimsPrincipal principal;
            try
            {
                principal = tokenHandler.ValidateToken(oldToken, new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateIssuer = true,
                    ValidIssuer = "goodsleep-api",
                    ValidateAudience = true,
                    ValidAudience = "goodsleep-app",
                    ValidateLifetime = false // Süresi dolmuş tokenları da yenile
                }, out _);
            }
            catch { return Unauthorized("Geçersiz token."); }

            var newDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(principal.Claims),
                Expires = DateTime.UtcNow.AddDays(30),
                Issuer = "goodsleep-api",
                Audience = "goodsleep-app",
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
            };

            var newToken = tokenHandler.CreateToken(newDescriptor);
            return Ok(new { token = tokenHandler.WriteToken(newToken) });
        }

        // --- Yardımcı metodlar ---

        private string BuildToken(User user)
        {
            var key = Encoding.ASCII.GetBytes(
                Environment.GetEnvironmentVariable("JWT_SECRET")
                ?? _configuration["JwtSettings:SecretKey"]!);

            var tokenHandler = new JwtSecurityTokenHandler();
            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new Claim(ClaimTypes.Email, user.Email),
                    new Claim("FamilyId", user.FamilyId)
                }),
                Expires = DateTime.UtcNow.AddDays(30),
                Issuer = "goodsleep-api",
                Audience = "goodsleep-app",
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }

        private static string GenerateSecureCode()
        {
            var bytes = new byte[4];
            RandomNumberGenerator.Fill(bytes);
            var number = Math.Abs(BitConverter.ToInt32(bytes, 0));
            return (number % 900000 + 100000).ToString();
        }
    }

    // --- DTO'lar (DataAnnotations ile server-side validasyon) ---

    public class RegisterDto
    {
        [Required(ErrorMessage = "Ad zorunludur.")]
        [StringLength(100, MinimumLength = 2, ErrorMessage = "Ad 2-100 karakter arasında olmalıdır.")]
        public string Name { get; set; } = string.Empty;

        [Required(ErrorMessage = "E-posta zorunludur.")]
        [EmailAddress(ErrorMessage = "Geçerli bir e-posta adresi girin.")]
        [StringLength(255)]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Şifre zorunludur.")]
        [StringLength(128, MinimumLength = 8, ErrorMessage = "Şifre en az 8 karakter olmalıdır.")]
        public string Password { get; set; } = string.Empty;
    }

    public class LoginDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        [StringLength(128)]
        public string Password { get; set; } = string.Empty;
    }

    public class DeleteAccountDto
    {
        [Required]
        [StringLength(128)]
        public string Password { get; set; } = string.Empty;
    }
}
