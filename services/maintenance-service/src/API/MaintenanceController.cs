[ApiController]
[Route("api/v1/maintenance")]
[Authorize(Roles = "MaintenanceManager,Admin")]
public class MaintenanceController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<MaintenanceController> _logger;

    public MaintenanceController(IMediator mediator, ILogger<MaintenanceController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [HttpPost("tasks")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<MaintenanceTaskDto>> CreateTask([FromBody] CreateMaintenanceTaskCommand command)
    {
        var result = await _mediator.Send(command);
        return CreatedAtAction(nameof(GetTask), new { id = result.Id }, result);
    }

    [HttpGet("tasks/{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<MaintenanceTaskDetailDto>> GetTask(Guid id)
    {
        var query = new GetMaintenanceTaskQuery { Id = id };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    [HttpPut("tasks/{id}/start")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> StartTask(Guid id)
    {
        var command = new StartMaintenanceTaskCommand { TaskId = id };
        await _mediator.Send(command);
        return NoContent();
    }

    [HttpPut("tasks/{id}/complete")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> CompleteTask(Guid id, [FromBody] CompleteMaintenanceTaskCommand command)
    {
        command.TaskId = id;
        await _mediator.Send(command);
        return NoContent();
    }

    [HttpGet("assets/{assetId}/tasks")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<MaintenanceTaskDto>>> GetAssetTasks(
        Guid assetId, 
        [FromQuery] MaintenanceStatus? status = null)
    {
        var query = new GetAssetMaintenanceTasksQuery { AssetId = assetId, Status = status };
        var result = await _mediator.Send(query);
        return Ok(result);
    }

    [HttpGet("scheduled")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<MaintenanceTaskDto>>> GetScheduledTasks(
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null)
    {
        var query = new GetScheduledTasksQuery { StartDate = startDate, EndDate = endDate };
        var result = await _mediator.Send(query);
        return Ok(result);
    }
}