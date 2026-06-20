using FluentValidation;

namespace Application.Commands.UpdateAssetStatus;

public class UpdateAssetStatusValidator : AbstractValidator<UpdateAssetStatusCommand>
{
    public UpdateAssetStatusValidator()
    {
        RuleFor(x => x.AssetId).NotEmpty();
        RuleFor(x => x.Status).NotNull();
    }
}
