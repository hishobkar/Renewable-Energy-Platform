using MediatR;

namespace Application.Queries.GetAssetDetails;

public class GetAssetQuery : IRequest<AssetDetailDto>
{
    public Guid Id { get; set; }
}