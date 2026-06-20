namespace Application.DTOs;

public class AssetTelemetryDto
{
    public string AssetId { get; set; } = string.Empty;
    public DateTime Timestamp { get; set; }
    public string MetricName { get; set; } = string.Empty;
    public double Value { get; set; }
    public string Unit { get; set; } = string.Empty;
}
