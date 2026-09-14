using System;
using System.ComponentModel.DataAnnotations;

namespace LittleDreams.Api.Models
{
    public class User
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        [Required]
        public string Name { get; set; } = string.Empty;

        [Required]
        public string Email { get; set; } = string.Empty;

        [Required]
        public string PasswordHash { get; set; } = string.Empty;

        [Required]
        public string FamilyId { get; set; } = string.Empty;
        // YENİ EKLENEN İLİŞKİ
        public Family? Family { get; set; }
        // Aile Davet Sistemi İçin (6 haneli geçici kod)
        public string? InviteCode { get; set; } 
        public DateTime? InviteCodeExpiry { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}