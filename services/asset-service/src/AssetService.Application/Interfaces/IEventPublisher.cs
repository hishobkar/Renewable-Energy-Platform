using Domain.Common;

namespace Application.Interfaces;

public interface IEventPublisher
{
    Task PublishAsync(DomainEvent domainEvent, CancellationToken cancellationToken);
}
