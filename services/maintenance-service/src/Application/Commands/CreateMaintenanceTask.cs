using MediatR;
using FluentValidation;

namespace Application.Commands.CreateMaintenanceTask;

public class CreateMaintenanceTaskCommand : IRequest<MaintenanceTaskDto>
{
    public Guid AssetId { get; set; }
    public MaintenanceType Type { get; set; }
    public string Title { get; set; }
    public string Description { get; set; }
    public DateTime ScheduledDate { get; set; }
    public MaintenancePriority Priority { get; set; }
    public List<MaintenanceStepDto> Steps { get; set; }
}

public class CreateMaintenanceTaskHandler : IRequestHandler<CreateMaintenanceTaskCommand, MaintenanceTaskDto>
{
    private readonly IMaintenanceRepository _repository;
    private readonly IAssetRepository _assetRepository;
    private readonly IEventPublisher _eventPublisher;
    private readonly ILogger<CreateMaintenanceTaskHandler> _logger;

    public CreateMaintenanceTaskHandler(
        IMaintenanceRepository repository,
        IAssetRepository assetRepository,
        IEventPublisher eventPublisher,
        ILogger<CreateMaintenanceTaskHandler> logger)
    {
        _repository = repository;
        _assetRepository = assetRepository;
        _eventPublisher = eventPublisher;
        _logger = logger;
    }

    public async Task<MaintenanceTaskDto> Handle(CreateMaintenanceTaskCommand command, CancellationToken cancellationToken)
    {
        // Validate asset exists
        var asset = await _assetRepository.GetByIdAsync(command.AssetId, cancellationToken);
        if (asset == null)
            throw new NotFoundException($"Asset {command.AssetId} not found");

        // Create maintenance task
        var task = new MaintenanceTask(
            Guid.NewGuid(),
            command.AssetId,
            command.Type,
            command.Title,
            command.Description,
            command.ScheduledDate,
            command.Priority
        );

        // Add steps
        if (command.Steps != null)
        {
            foreach (var stepDto in command.Steps)
            {
                task.Steps.Add(new MaintenanceStep(
                    Guid.NewGuid(),
                    stepDto.Order,
                    stepDto.Description,
                    stepDto.EstimatedDuration
                ));
            }
        }

        // Store in repository
        await _repository.AddAsync(task, cancellationToken);
        await _repository.SaveChangesAsync(cancellationToken);

        // Publish domain events
        foreach (var domainEvent in task.DomainEvents)
        {
            await _eventPublisher.PublishAsync(domainEvent, cancellationToken);
        }

        _logger.LogInformation("Maintenance task {TaskId} created for asset {AssetId}", task.Id, task.AssetId);
        
        return MapToDto(task);
    }

    private MaintenanceTaskDto MapToDto(MaintenanceTask task)
    {
        return new MaintenanceTaskDto
        {
            Id = task.Id,
            AssetId = task.AssetId,
            Type = task.Type,
            Priority = task.Priority,
            Status = task.Status,
            Title = task.Title,
            Description = task.Description,
            ScheduledDate = task.ScheduledDate,
            Steps = task.Steps.Select(s => new MaintenanceStepDto
            {
                Order = s.Order,
                Description = s.Description,
                EstimatedDuration = s.EstimatedDuration
            }).ToList(),
            Notes = task.Notes.Select(n => new MaintenanceNoteDto
            {
                Content = n.Content,
                UserId = n.UserId,
                CreatedAt = n.CreatedAt
            }).ToList()
        };
    }
}