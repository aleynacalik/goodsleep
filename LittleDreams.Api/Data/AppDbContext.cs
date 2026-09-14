using Microsoft.EntityFrameworkCore;
using LittleDreams.Api.Models;

namespace LittleDreams.Api.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<SleepLog> SleepLogs { get; set; }
        public DbSet<User> Users { get; set; }
        public DbSet<Family> Families { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Sık sorgulanan kolonlara index ekle (performans)
            modelBuilder.Entity<User>()
                .HasIndex(u => u.Email)
                .IsUnique();

            modelBuilder.Entity<User>()
                .HasIndex(u => u.FamilyId);

            modelBuilder.Entity<SleepLog>()
                .HasIndex(s => s.FamilyId);

            modelBuilder.Entity<SleepLog>()
                .HasIndex(s => s.StartTime);

            modelBuilder.Entity<Family>()
                .HasIndex(f => f.InviteCode);

            // CoachProgress maksimum boyut (JSON bomb koruması)
            modelBuilder.Entity<Family>()
                .Property(f => f.CoachProgress)
                .HasMaxLength(65536); // 64KB

            // Foreign key constraint'ler — orphaned kayıt oluşmasını engeller
            modelBuilder.Entity<User>()
                .HasOne(u => u.Family)
                .WithMany(f => f.Users)
                .HasForeignKey(u => u.FamilyId)
                .OnDelete(DeleteBehavior.Restrict);

            modelBuilder.Entity<SleepLog>()
                .HasOne<Family>()
                .WithMany(f => f.SleepLogs)
                .HasForeignKey(s => s.FamilyId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}
