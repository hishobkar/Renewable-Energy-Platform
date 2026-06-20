using Application.Interfaces;
using Domain.Entities;
using Domain.Enums;
using MediatR;

namespace Application.Commands.UpdateAssetStatus;

public class UpdateAssetStatusHandler : IRequestHandler<UpdateAssetStatusCommand>
{
    private readonly IAssetRepository _repository;

    public UpdateAssetStatusHandler(IAssetRepository repository)
    {
        _repository = repository;
    }

    public async Task Handle(UpdateAssetStatusCommand command, CancellationToken cancellationToken)
    {
        var asset = await _repository.GetByIdAsync(command.AssetId, cancellationToken);
        if (asset == null)
        {
            throw new Exception($"Asset {command.AssetId} not found");
        }

        asset.UpdateStatus(command.Status);
        await _repository.UpdateAsync(asset, cancellationToken);
        await _repository.SaveChangesAsync(cancellationToken);
    }
}
