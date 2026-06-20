namespace Domain.Entities;

public class MaintenanceSchedule
{
    public Guid Id { get; private set; }
    public Guid AssetId { get; private set; }
    public DateTime ScheduledDate { get; private set; }
    public DateTime? CompletedDate { get; private set; }
    public string Type { get; private set; }
    public string Notes { get; private set; }

    private MaintenanceSchedule() { Type = string.Empty; Notes = string.Empty; }

    public MaintenanceSchedule(Guid assetId, DateTime scheduledDate, string type, string notes = "")
    {
        Id = Guid.NewGuid();
        AssetId = assetId;
        ScheduledDate = scheduledDate;
        Type = type;
        Notes = notes;
    }

    public void Complete()
    {
        CompletedDate = DateTime.UtcNow;
    }
}
