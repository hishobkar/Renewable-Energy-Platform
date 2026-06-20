using Domain.Entities;

namespace Domain.Repositories;

public interface IMaintenanceRepository
{
    Task<IEnumerable<MaintenanceSchedule>> GetByAssetIdAsync(Guid assetId, CancellationToken cancellationToken);
    Task AddAsync(MaintenanceSchedule schedule, CancellationToken cancellationToken);
    Task SaveChangesAsync(CancellationToken cancellationToken);
}
