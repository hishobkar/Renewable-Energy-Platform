using Domain.Entities;

namespace Domain.Services;

public interface IAssetValidationService
{
    Task ValidateAsync(Asset asset);
}
