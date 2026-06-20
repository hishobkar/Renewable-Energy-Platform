using Domain.Common;

namespace Domain.Services;

public interface IDomainEventService
{
    Task PublishAsync(DomainEvent domainEvent, CancellationToken cancellationToken);
}
