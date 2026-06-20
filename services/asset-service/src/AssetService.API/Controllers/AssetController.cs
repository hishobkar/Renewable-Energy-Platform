using MediatR;
using Microsoft.AspNetCore.Mvc;
using Application.Commands.RegisterAsset;
using Application.Commands.UpdateAssetStatus;
using Application.Queries.GetAssetDetails;
using Application.Queries.ListAssets;
using Application.DTOs;

namespace API.Controllers;

[ApiController]
[Route("api/v1/assets")]
public class AssetController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<AssetController> _logger;

    public AssetController(IMediator mediator, ILogger<AssetController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [HttpPost]
    [ProducesResponseType(typeof(AssetDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<AssetDto>> RegisterAsset([FromBody] RegisterAssetCommand command)
    {
        try
        {
            var result = await _mediator.Send(command);
            return CreatedAtAction(nameof(GetAsset), new { id = result.Id }, result);
        }
        catch(Exception ex)
        {
            _logger.LogError(ex, "Error occurred while registering asset.");
            return BadRequest(new { message = ex.Message, inner = ex.InnerException?.Message });    
        }
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(AssetDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AssetDetailDto>> GetAsset(Guid id)
    {
        var query = new GetAssetQuery { Id = id };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    [HttpPut("{id:guid}/status")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateAssetStatus(Guid id, [FromBody] UpdateAssetStatusCommand command)
    {
        command.AssetId = id;
        await _mediator.Send(command);
        return NoContent();
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<AssetDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<AssetDto>>> ListAssets([FromQuery] AssetFilter filter)
    {
        var query = new ListAssetsQuery { Filter = filter };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    [HttpDelete("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteAsset(Guid id)
    {
        await _mediator.Send(new Application.Commands.DeleteAsset.DeleteAssetCommand { AssetId = id });
        return NoContent();
    }
}
