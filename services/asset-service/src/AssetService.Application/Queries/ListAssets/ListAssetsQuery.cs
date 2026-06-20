using MediatR;

namespace Application.Queries.ListAssets;

public class ListAssetsQuery : IRequest<IEnumerable<AssetDto>>
{
    public AssetFilter Filter { get; set; } = new();
}
