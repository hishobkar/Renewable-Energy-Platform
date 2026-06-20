namespace Application.Queries.ListAssets;

public class AssetFilter
{
    public string? AssetType { get; set; }
    public string? Status { get; set; }
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 50;
}
