namespace Application.Interfaces;

public interface IAssetService
{
    Task<AssetDto> RegisterAssetAsync(RegisterAssetCommand command, CancellationToken cancellationToken);
    Task UpdateAssetStatusAsync(UpdateAssetStatusCommand command, CancellationToken cancellationToken);
    Task<IEnumerable<AssetDto>> ListAssetsAsync(AssetFilter filter, CancellationToken cancellationToken);
}
