using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace LittleDreams.Api.Models
{
    public class Family
    {
        [Key]
        public string Id { get; set; } = Guid.NewGuid().ToString();

        // Ailenin soyadı (Örn: Pekediz Ailesi)
        public string FamilyName { get; set; } = "Ailemiz";

        // Bebeğin Adı (Örn: Deniz)
        public string BabyName { get; set; } = "Bebeğimiz";

        // Bebeğin Doğum Tarihi (İsteğe bağlı)
        public DateTime? BabyBirthDate { get; set; }

        public string? InviteCode { get; set; }
        public DateTime? InviteCodeExpires { get; set; }
        public string? CoachProgress { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Bu aileye ait olan uyku kayıtları ve kullanıcılar
        public ICollection<User> Users { get; set; } = new List<User>();
        public ICollection<SleepLog> SleepLogs { get; set; } = new List<SleepLog>();
    }
}