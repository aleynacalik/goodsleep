using System;
using System.ComponentModel.DataAnnotations;

namespace LittleDreams.Api.Models
{
    public class SleepLog
    {
        [Key]
        public Guid Id { get; set; } = Guid.NewGuid();

        // Senkronizasyon için aile veya hesap ID'si
        [Required]
        public string FamilyId { get; set; } = string.Empty;

        [Required]
        public DateTime StartTime { get; set; }

        [Required]
        public DateTime EndTime { get; set; }

        [Required]
        public int DurationInSeconds { get; set; }

        // Kaydın ne zaman oluşturulduğunu takip etmek için
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow; 
    }
}