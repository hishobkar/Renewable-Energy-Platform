namespace Application.Commands.DeleteAsset;

public class DeleteAssetHandler : IRequestHandler<DeleteAssetCommand>
{
    private readonly IAssetRepository _repository;

    public DeleteAssetHandler(IAssetRepository repository)
    {
        _repository = repository;
    }

    public async Task Handle(DeleteAssetCommand command, CancellationToken cancellationToken)
    {
        var asset = await _repository.GetByIdAsync(command.AssetId, cancellationToken);
        if (asset == null)
            throw new Exception($"Asset {command.AssetId} not found");

        await _repository.DeleteAsync(asset, cancellationToken);
        await _repository.SaveChangesAsync(cancellationToken);
    }
}
