using Domain.Entities;
using Domain.Enums;
using Domain.ValueObjects;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Context;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    public DbSet<Asset> Assets => Set<Asset>();
    public DbSet<MaintenanceSchedule> MaintenanceSchedules => Set<MaintenanceSchedule>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<Asset>(entity =>
        {
            entity.HasKey(a => a.Id);
            entity.Property(a => a.Name).IsRequired().HasMaxLength(200);
            entity.Property(a => a.Type).IsRequired().HasConversion<string>();
            entity.Property(a => a.Status).IsRequired().HasConversion<string>();
            entity.Property(a => a.InstallationDate).IsRequired();
            entity.Property(a => a.LastMaintenanceDate);

            entity.OwnsOne(a => a.Location, loc =>
            {
                loc.Property(l => l.Latitude).HasColumnName("Latitude").IsRequired();
                loc.Property(l => l.Longitude).HasColumnName("Longitude").IsRequired();
                loc.Property(l => l.Elevation).HasColumnName("Elevation");
            });

            entity.OwnsOne(a => a.Capacity, cap =>
            {
                cap.Property(c => c.Value).HasColumnName("CapacityValue").IsRequired();
                cap.Property(c => c.Unit).HasColumnName("CapacityUnit").HasDefaultValue("MW");
            });

            entity.Property(a => a.Metadata)
                .HasConversion(
                    d => System.Text.Json.JsonSerializer.Serialize(d, (System.Text.Json.JsonSerializerOptions?)null),
                    s => System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(s, (System.Text.Json.JsonSerializerOptions?)null) ?? new())
                .HasColumnType("text");

            entity.Ignore(a => a.DomainEvents);

            entity.HasMany(a => a.MaintenanceHistory)
                  .WithOne()
                  .HasForeignKey(m => m.AssetId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<MaintenanceSchedule>(entity =>
        {
            entity.HasKey(m => m.Id);
            entity.Property(m => m.AssetId).IsRequired();
            entity.Property(m => m.ScheduledDate).IsRequired();
            entity.Property(m => m.Type).IsRequired().HasMaxLength(100);
            entity.Property(m => m.Notes).HasMaxLength(1000);
        });
    }
}
