using MediatR;

namespace Application.Queries.GetAssetTelemetry;

public class GetAssetTelemetryQuery : IRequest<IEnumerable<AssetTelemetryDto>>
{
    public Guid AssetId { get; set; }
    public int Limit { get; set; } = 50;
}
