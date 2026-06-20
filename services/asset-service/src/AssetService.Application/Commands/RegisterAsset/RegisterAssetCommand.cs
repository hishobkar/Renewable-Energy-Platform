using MediatR;

namespace Application.Commands.RegisterAsset;

public class RegisterAssetCommand : IRequest<AssetDto>
{
    public string Name { get; set; }
    public AssetType Type { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double Capacity { get; set; }
    public Dictionary<string, string> Metadata { get; set; }
}