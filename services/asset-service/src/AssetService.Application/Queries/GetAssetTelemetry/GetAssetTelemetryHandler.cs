namespace Application.Queries.GetAssetTelemetry;

public class GetAssetTelemetryHandler : IRequestHandler<GetAssetTelemetryQuery, IEnumerable<AssetTelemetryDto>>
{
    public Task<IEnumerable<AssetTelemetryDto>> Handle(GetAssetTelemetryQuery query, CancellationToken cancellationToken)
    {
        // Telemetry data is served by the dedicated telemetry-service (Python/DynamoDB).
        // This handler returns an empty list; the controller redirects to the telemetry API.
        return Task.FromResult(Enumerable.Empty<AssetTelemetryDto>());
    }
}
