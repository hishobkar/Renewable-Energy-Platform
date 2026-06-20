using MediatR;

namespace Application.Commands.DeleteAsset;

public class DeleteAssetCommand : IRequest
{
    public Guid AssetId { get; set; }
}
