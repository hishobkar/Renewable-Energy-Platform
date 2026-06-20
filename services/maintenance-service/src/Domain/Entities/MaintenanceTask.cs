using Domain.Common;
using Domain.Enums;

namespace Domain.Entities;

public class MaintenanceTask : AggregateRoot
{
    public Guid Id { get; private set; }
    public Guid AssetId { get; private set; }
    public MaintenanceType Type { get; private set; }
    public MaintenancePriority Priority { get; private set; }
    public MaintenanceStatus Status { get; private set; }
    public string Title { get; private set; }
    public string Description { get; private set; }
    public DateTime ScheduledDate { get; private set; }
    public DateTime? StartedAt { get; private set; }
    public DateTime? CompletedAt { get; private set; }
    public string AssignedTo { get; private set; }
    public List<MaintenanceStep> Steps { get; private set; }
    public List<MaintenanceNote> Notes { get; private set; }
    public WorkOrder WorkOrder { get; private set; }
    public Asset AssociatedAsset { get; private set; }
    public TimeSpan EstimatedDuration { get; private set; }
    public TimeSpan? ActualDuration { get; private set; }

    private MaintenanceTask() { }

    public MaintenanceTask(Guid id, Guid assetId, MaintenanceType type, 
        string title, string description, DateTime scheduledDate, 
        MaintenancePriority priority = MaintenancePriority.Medium)
    {
        Id = id;
        AssetId = assetId;
        Type = type;
        Title = title;
        Description = description;
        ScheduledDate = scheduledDate;
        Priority = priority;
        Status = MaintenanceStatus.Scheduled;
        Steps = new List<MaintenanceStep>();
        Notes = new List<MaintenanceNote>();
        
        AddDomainEvent(new MaintenanceTaskCreatedEvent(id, assetId, type, title));
    }

    public void StartMaintenance(string userId)
    {
        Status = MaintenanceStatus.InProgress;
        StartedAt = DateTime.UtcNow;
        AssignedTo = userId;
        
        AddDomainEvent(new MaintenanceStartedEvent(Id, userId, DateTime.UtcNow));
    }

    public void CompleteMaintenance(TimeSpan? actualDuration = null)
    {
        Status = MaintenanceStatus.Completed;
        CompletedAt = DateTime.UtcNow;
        ActualDuration = actualDuration ?? DateTime.UtcNow - StartedAt.Value;
        
        AddDomainEvent(new MaintenanceCompletedEvent(Id, DateTime.UtcNow));
    }

    public void AddNote(string content, string userId)
    {
        Notes.Add(new MaintenanceNote(Guid.NewGuid(), content, userId, DateTime.UtcNow));
        AddDomainEvent(new MaintenanceNoteAddedEvent(Id, content, userId));
    }

    public void UpdatePriority(MaintenancePriority newPriority)
    {
        var oldPriority = Priority;
        Priority = newPriority;
        AddDomainEvent(new MaintenancePriorityChangedEvent(Id, oldPriority, newPriority));
    }

    public void GenerateWorkOrder(WorkOrder workOrder)
    {
        WorkOrder = workOrder;
        AddDomainEvent(new WorkOrderGeneratedEvent(Id, workOrder.Number));
    }
}