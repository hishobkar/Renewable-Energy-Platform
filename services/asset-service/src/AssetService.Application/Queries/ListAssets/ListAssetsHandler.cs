using Application.Interfaces;
using Domain.Enums;
using MediatR;

namespace Application.Queries.ListAssets;

public class ListAssetsHandler : IRequestHandler<ListAssetsQuery, IEnumerable<AssetDto>>
{
    private readonly IAssetRepository _repository;

    public ListAssetsHandler(IAssetRepository repository)
    {
        _repository = repository;
    }

    public async Task<IEnumerable<AssetDto>> Handle(ListAssetsQuery request, CancellationToken cancellationToken)
    {
        var assets = await _repository.GetAllAsync(cancellationToken);
        var filter = request.Filter;

        return assets
            .Where(a => filter.AssetType == null || a.Type.ToString() == filter.AssetType)
            .Where(a => filter.Status == null || a.Status.ToString() == filter.Status)
            .Select(MapToDto);
    }

    private static AssetDto MapToDto(Domain.Entities.Asset asset) => new()
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
