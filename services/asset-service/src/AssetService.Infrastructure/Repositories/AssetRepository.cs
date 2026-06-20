using Application.Interfaces;
using Domain.Entities;
using Domain.Enums;
using Infrastructure.Context;
using Microsoft.EntityFrameworkCore;

namespace Infrastructure.Repositories;

public class AssetRepository : IAssetRepository
{
    private readonly ApplicationDbContext _context;
    private readonly DbSet<Asset> _dbSet;

    public AssetRepository(ApplicationDbContext context)
    {
        _context = context;
        _dbSet = context.Set<Asset>();
    }

    public async Task<Asset> GetByIdAsync(Guid id, CancellationToken cancellationToken)
    {
        return await _dbSet
            .Include(a => a.MaintenanceHistory)
            .FirstOrDefaultAsync(a => a.Id == id, cancellationToken);
    }

    public async Task<IEnumerable<Asset>> GetAllAsync(CancellationToken cancellationToken)
    {
        return await _dbSet.ToListAsync(cancellationToken);
    }

    public async Task<IEnumerable<Asset>> GetByTypeAsync(AssetType type, CancellationToken cancellationToken)
    {
        return await _dbSet
            .Where(a => a.Type == type)
            .ToListAsync(cancellationToken);
    }

    public async Task AddAsync(Asset asset, CancellationToken cancellationToken)
    {
        await _dbSet.AddAsync(asset, cancellationToken);
    }

    public Task UpdateAsync(Asset asset, CancellationToken cancellationToken)
    {
        _dbSet.Update(asset);
        return Task.CompletedTask;
    }

    public Task DeleteAsync(Asset asset, CancellationToken cancellationToken)
    {
        _dbSet.Remove(asset);
        return Task.CompletedTask;
    }

    public async Task SaveChangesAsync(CancellationToken cancellationToken)
    {
        await _context.SaveChangesAsync(cancellationToken);
    }
}
