namespace Application.Queries.GetAssetDetails;

public class GetAssetHandler : IRequestHandler<GetAssetQuery, AssetDetailDto>
{
    private readonly IAssetRepository _repository;
    private readonly ICacheService _cache;

    public GetAssetHandler(IAssetRepository repository, ICacheService cache)
    {
        _repository = repository;
        _cache = cache;
    }

    public async Task<AssetDetailDto> Handle(GetAssetQuery query, CancellationToken cancellationToken)
    {
        var cacheKey = $"asset:{query.Id}";
        var cached = await _cache.GetAsync<AssetDetailDto>(cacheKey);
        if (cached != null)
            return cached;

        var asset = await _repository.GetByIdAsync(query.Id, cancellationToken);
        if (asset == null)
            throw new NotFoundException($"Asset {query.Id} not found");

        var dto = MapToDetailDto(asset);
        await _cache.SetAsync(cacheKey, dto, TimeSpan.FromMinutes(5));

        return dto;
    }

    private static AssetDetailDto MapToDetailDto(Asset asset) => new()
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