using AutoMapper;

namespace Application.Mappings;

public class AssetMappingProfile : Profile
{
    public AssetMappingProfile()
    {
        CreateMap<Asset, AssetDto>()
            .ForMember(d => d.Type, o => o.MapFrom(s => s.Type.ToString()))
            .ForMember(d => d.Status, o => o.MapFrom(s => s.Status.ToString()))
            .ForMember(d => d.Latitude, o => o.MapFrom(s => s.Location.Latitude))
            .ForMember(d => d.Longitude, o => o.MapFrom(s => s.Location.Longitude))
            .ForMember(d => d.CapacityMW, o => o.MapFrom(s => s.Capacity.Value));

        CreateMap<Asset, AssetDetailDto>()
            .IncludeBase<Asset, AssetDto>();
    }
}
