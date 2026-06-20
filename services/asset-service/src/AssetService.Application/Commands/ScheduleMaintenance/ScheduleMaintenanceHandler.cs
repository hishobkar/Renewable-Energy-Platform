using Domain.Entities;

namespace Application.Commands.ScheduleMaintenance;

public class ScheduleMaintenanceHandler : IRequestHandler<ScheduleMaintenanceCommand, AssetMaintenanceDto>
{
    private readonly IAssetRepository _repository;

    public ScheduleMaintenanceHandler(IAssetRepository repository)
    {
        _repository = repository;
    }

    public async Task<AssetMaintenanceDto> Handle(ScheduleMaintenanceCommand command, CancellationToken cancellationToken)
    {
        var asset = await _repository.GetByIdAsync(command.AssetId, cancellationToken);
        if (asset == null)
            throw new Exception($"Asset {command.AssetId} not found");

        var schedule = new MaintenanceSchedule(command.AssetId, command.ScheduledDate, command.Type, command.Notes);
        asset.ScheduleMaintenance(schedule);
        await _repository.UpdateAsync(asset, cancellationToken);
        await _repository.SaveChangesAsync(cancellationToken);

        return new AssetMaintenanceDto
        {
            Id = schedule.Id,
            AssetId = schedule.AssetId,
            ScheduledDate = schedule.ScheduledDate,
            Type = schedule.Type,
            Notes = schedule.Notes
        };
    }
}
