using Domain.Common;
using Domain.Events;

namespace Domain.Entities;

public class Asset : AggregateRoot
{
    public Guid Id { get; private set; }
    public string Name { get; private set; }
    public AssetType Type { get; private set; }
    public AssetStatus Status { get; private set; }
    public GeographicLocation Location { get; private set; }
    public Capacity Capacity { get; private set; }
    public DateTime InstallationDate { get; private set; }
    public DateTime? LastMaintenanceDate { get; private set; }
    public Dictionary<string, string> Metadata { get; private set; }

    public List<MaintenanceSchedule> MaintenanceHistory { get; private set; } = new();

    private Asset() { }

    public Asset(Guid id, string name, AssetType type, GeographicLocation location, Capacity capacity)
    {
        Id = id;
        Name = name;
        Type = type;
        Status = AssetStatus.Active;
        Location = location;
        Capacity = capacity;
        InstallationDate = DateTime.UtcNow;
        Metadata = new Dictionary<string, string>();

        AddDomainEvent(new AssetRegisteredEvent(id, name, type, location));
    }

    public void UpdateStatus(AssetStatus newStatus)
    {
        var oldStatus = Status;
        Status = newStatus;
        AddDomainEvent(new AssetStatusChangedEvent(Id, oldStatus, newStatus));
    }

    public void ScheduleMaintenance(MaintenanceSchedule schedule)
    {
        MaintenanceHistory.Add(schedule);
        AddDomainEvent(new MaintenanceScheduledEvent(Id, schedule.ScheduledDate));
    }

    public void RecordMaintenance()
    {
        LastMaintenanceDate = DateTime.UtcNow;
        AddDomainEvent(new MaintenancePerformedEvent(Id, DateTime.UtcNow));
    }
}