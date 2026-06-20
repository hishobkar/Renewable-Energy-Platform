using MediatR;

namespace Application.Queries.GetAssetMaintenanceHistory;

public class GetAssetMaintenanceHistoryQuery : IRequest<IEnumerable<AssetMaintenanceDto>>
{
    public Guid AssetId { get; set; }
}
