using MediatR;

namespace Application.Commands.ScheduleMaintenance;

public class ScheduleMaintenanceCommand : IRequest<AssetMaintenanceDto>
{
    public Guid AssetId { get; set; }
    public DateTime ScheduledDate { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
}
