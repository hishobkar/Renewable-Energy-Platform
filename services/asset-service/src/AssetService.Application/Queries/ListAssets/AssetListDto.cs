namespace Application.Queries.ListAssets;

public class AssetListDto
{
    public IEnumerable<AssetDto> Items { get; set; } = Enumerable.Empty<AssetDto>();
    public int Total { get; set; }
    public int Page { get; set; }
    public int PageSize { get; set; }
}
