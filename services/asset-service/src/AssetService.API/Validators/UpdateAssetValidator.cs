using FluentValidation;

namespace API.Validators;

public class UpdateAssetValidator : AbstractValidator<UpdateAssetStatusCommand>
{
    public UpdateAssetValidator()
    {
        RuleFor(x => x.AssetId).NotEmpty();
        RuleFor(x => x.Status).IsInEnum();
    }
}
