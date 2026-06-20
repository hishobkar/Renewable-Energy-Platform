namespace Application.Commands.RegisterAsset;

public class RegisterAssetHandler : IRequestHandler<RegisterAssetCommand, AssetDto>
{
    private readonly IAssetRepository _repository;
    private readonly IEventPublisher _eventPublisher;

    public RegisterAssetHandler(IAssetRepository repository, IEventPublisher eventPublisher)
    {
        _repository = repository;
        _eventPublisher = eventPublisher;
    }

    public async Task<AssetDto> Handle(RegisterAssetCommand command, CancellationToken cancellationToken)
    {
        var location = new GeographicLocation(command.Latitude, command.Longitude);
        var capacity = new Capacity(command.Capacity);
        
        var asset = new Asset(
            Guid.NewGuid(),
            command.Name,
            command.Type,
            location,
            capacity
        );

        if (command.Metadata != null)
        {
            foreach (var kvp in command.Metadata)
            {
                asset.Metadata[kvp.Key] = kvp.Value;
            }
        }

        await _repository.AddAsync(asset, cancellationToken);
        await _repository.SaveChangesAsync(cancellationToken);

        // Publish domain events
        foreach (var domainEvent in asset.DomainEvents)
        {
            await _eventPublisher.PublishAsync(domainEvent, cancellationToken);
        }

        return MapToDto(asset);
    }

    private static AssetDto MapToDto(Asset asset) => new()
    {
        Id = asset.Id,
        Name = asset.Name,
        Type = asset.Type.ToString(),
        Status = asset.Status.ToString(),
        CapacityMW = asset.Capacity.Value,
        Latitude = asset.Location.Latitude,
        Longitude = asset.Location.Longitude,
        InstallationDate = asset.InstallationDate,
        LastMaintenanceDate = asset.LastMaintenanceDate,
        Metadata = asset.Metadata
    };
}