namespace Domain.ValueObjects;

public class GeographicLocation
{
    public double Latitude { get; }
    public double Longitude { get; }
    public double? Elevation { get; }

    public GeographicLocation(double latitude, double longitude, double? elevation = null)
    {
        Latitude = latitude;
        Longitude = longitude;
        Elevation = elevation;
    }
}
