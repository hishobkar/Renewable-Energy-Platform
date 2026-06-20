namespace Application.Commands.RegisterAsset;

public class RegisterAssetValidator : AbstractValidator<RegisterAssetCommand>
{
    public RegisterAssetValidator()
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Latitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.Longitude).InclusiveBetween(-180, 180);
        RuleFor(x => x.Capacity).GreaterThan(0);
    }
}
