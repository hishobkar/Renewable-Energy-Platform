namespace Domain.Events;

public class AssetRegisteredEvent : DomainEvent
{
    public Guid AssetId { get; }
    public string Name { get; }
    public AssetType Type { get; }
    public GeographicLocation Location { get; }

    public AssetRegisteredEvent(Guid assetId, string name, AssetType type, GeographicLocation location)
    {
        AssetId = assetId;
        Name = name;
        Type = type;
        Location = location;
    }
}

public class AssetStatusChangedEvent : DomainEvent
{
    public Guid AssetId { get; }
    public AssetStatus OldStatus { get; }
    public AssetStatus NewStatus { get; }

    public AssetStatusChangedEvent(Guid assetId, AssetStatus oldStatus, AssetStatus newStatus)
    {
        AssetId = assetId;
        OldStatus = oldStatus;
        NewStatus = newStatus;
    }
}

public class MaintenanceScheduledEvent : DomainEvent
{
    public Guid AssetId { get; }
    public DateTime ScheduledDate { get; }

    public MaintenanceScheduledEvent(Guid assetId, DateTime scheduledDate)
    {
        AssetId = assetId;
        ScheduledDate = scheduledDate;
    }
}

public class MaintenancePerformedEvent : DomainEvent
{
    public Guid AssetId { get; }
    public DateTime PerformedDate { get; }

    public MaintenancePerformedEvent(Guid assetId, DateTime performedDate)
    {
        AssetId = assetId;
        PerformedDate = performedDate;
    }
}