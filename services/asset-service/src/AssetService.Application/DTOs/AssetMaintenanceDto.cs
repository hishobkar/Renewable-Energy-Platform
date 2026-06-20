namespace Application.DTOs;

public class AssetMaintenanceDto
{
    public Guid Id { get; set; }
    public Guid AssetId { get; set; }
    public DateTime ScheduledDate { get; set; }
    public DateTime? CompletedDate { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Notes { get; set; } = string.Empty;
}
