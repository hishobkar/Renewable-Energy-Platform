using Domain.Entities;
using Domain.Enums;

namespace Domain.Repositories;

public interface IAssetRepository
{
    Task<Asset> GetByIdAsync(Guid id, CancellationToken cancellationToken);
    Task<IEnumerable<Asset>> GetAllAsync(CancellationToken cancellationToken);
    Task<IEnumerable<Asset>> GetByTypeAsync(AssetType type, CancellationToken cancellationToken);
    Task AddAsync(Asset asset, CancellationToken cancellationToken);
    Task UpdateAsync(Asset asset, CancellationToken cancellationToken);
    Task DeleteAsync(Asset asset, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
