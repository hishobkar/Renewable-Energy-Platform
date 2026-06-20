namespace Application.Queries.GetAssetMaintenanceHistory;

public class GetAssetMaintenanceHistoryHandler : IRequestHandler<GetAssetMaintenanceHistoryQuery, IEnumerable<AssetMaintenanceDto>>
{
    private readonly IAssetRepository _repository;

    public GetAssetMaintenanceHistoryHandler(IAssetRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<AssetMaintenanceDto>> Handle(GetAssetMaintenanceHistoryQuery query, CancellationToken cancellationToken)
    {
        var asset = await _repository.GetByIdAsync(query.AssetId, cancellationToken);
        if (asset == null)
            throw new Exception($"Asset {query.AssetId} not found");

        return asset.MaintenanceHistory.Select(m => new AssetMaintenanceDto
        {
            Id = m.Id,
            AssetId = m.AssetId,
            ScheduledDate = m.ScheduledDate,
            CompletedDate = m.CompletedDate,
            Type = m.Type,
            Notes = m.Notes
        });
    }
}
