namespace Application.DTOs;

public class AssetDetailDto : AssetDto
{
    public List<AssetMaintenanceDto> MaintenanceHistory { get; set; } = new();
    public AssetTelemetryDto? LatestTelemetry { get; set; }
}
