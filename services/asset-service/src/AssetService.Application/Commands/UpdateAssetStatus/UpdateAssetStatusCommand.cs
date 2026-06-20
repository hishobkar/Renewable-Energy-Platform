using MediatR;
using Domain.Enums;

namespace Application.Commands.UpdateAssetStatus;

public class UpdateAssetStatusCommand : IRequest
{
    public Guid AssetId { get; set; }
    public AssetStatus Status { get; set; }
}
