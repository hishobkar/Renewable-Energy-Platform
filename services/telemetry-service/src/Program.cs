// Program.cs
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using System.Text.Json;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DataModel;
using Amazon.SQS;
using Amazon.Runtime;

var builder = WebApplication.CreateBuilder(args);

// AWS Configuration
var awsOptions = builder.Configuration.GetAWSOptions();
builder.Services.AddDefaultAWSOptions(awsOptions);
builder.Services.AddAWSService<IAmazonDynamoDB>();
builder.Services.AddAWSService<IAmazonSQS>();
builder.Services.AddScoped<IDynamoDBContext, DynamoDBContext>();

// OpenTelemetry Configuration
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProviderBuilder =>
        tracerProviderBuilder
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddAWSInstrumentation()
            .AddXRayTraceId()
            .AddOtlpExporter())
    .WithMetrics(metricsProviderBuilder =>
        metricsProviderBuilder
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddPrometheusExporter());

// AWS X-Ray
builder.Services.AddXRay();

// Add Health Checks
builder.Services.AddHealthChecks()
    .AddCheck<DynamoDbHealthCheck>("dynamodb")
    .AddCheck<SqsHealthCheck>("sqs");

// Add Services
builder.Services.AddSingleton<TelemetryProcessor>();
builder.Services.AddSingleton<EventPublisher>();

var app = builder.Build();

// Middleware
app.UseXRay("TelemetryService");
app.UseOpenTelemetryPrometheusScrapingEndpoint();

// Health Check Endpoint
app.MapHealthChecks("/health", new HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        var result = JsonSerializer.Serialize(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new
            {
                name = e.Key,
                status = e.Value.Status.ToString(),
                description = e.Value.Description
            })
        });
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(result);
    }
});

// Telemetry Endpoints
app.MapPost("/api/v1/telemetry", async (
    [FromBody] TelemetryData data,
    TelemetryProcessor processor,
    ILogger<Program> logger) =>
{
    try
    {
        using var activity = Telemetry.ActivitySource.StartActivity("ProcessTelemetry");
        activity?.SetTag("asset.id", data.AssetId);
        activity?.SetTag("telemetry.type", data.Type);

        await processor.ProcessTelemetryAsync(data);
        return Results.Accepted();
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Error processing telemetry data");
        return Results.Problem("Error processing telemetry data");
    }
})
.WithName("ReceiveTelemetry")
.WithOpenApi();

app.MapPost("/api/v1/telemetry/batch", async (
    [FromBody] IEnumerable<TelemetryData> batch,
    TelemetryProcessor processor) =>
{
    await processor.ProcessBatchAsync(batch);
    return Results.Accepted();
});

app.Run();

// Models
public class TelemetryData
{
    public string AssetId { get; set; }
    public string Type { get; set; }
    public DateTime Timestamp { get; set; }
    public Dictionary<string, double> Metrics { get; set; }
    public string Source { get; set; }
}

// Domain Models for DynamoDB
[DynamoDBTable("Telemetry")]
public class TelemetryRecord
{
    [DynamoDBHashKey]
    public string PartitionKey { get; set; } // assetId#YYYY-MM-DD
    
    [DynamoDBRangeKey]
    public string SortKey { get; set; } // timestamp
    
    public string AssetId { get; set; }
    public DateTime Timestamp { get; set; }
    public string Type { get; set; }
    public Dictionary<string, double> Metrics { get; set; }
    public string Source { get; set; }
    public string DataType { get; set; }
    public int TTL { get; set; } // Time-to-live for data retention
}

// Processor
public class TelemetryProcessor
{
    private readonly IDynamoDBContext _dynamoDbContext;
    private readonly EventPublisher _eventPublisher;
    private readonly ILogger<TelemetryProcessor> _logger;
    private readonly Telemetry.ActivitySource _activitySource;

    public TelemetryProcessor(
        IDynamoDBContext dynamoDbContext,
        EventPublisher eventPublisher,
        ILogger<TelemetryProcessor> logger)
    {
        _dynamoDbContext = dynamoDbContext;
        _eventPublisher = eventPublisher;
        _logger = logger;
        _activitySource = new Telemetry.ActivitySource("TelemetryService");
    }

    public async Task ProcessTelemetryAsync(TelemetryData data)
    {
        using var activity = _activitySource.StartActivity("StoreTelemetry");
        
        // Store in DynamoDB
        var record = new TelemetryRecord
        {
            PartitionKey = $"{data.AssetId}#{data.Timestamp:yyyy-MM-dd}",
            SortKey = data.Timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
            AssetId = data.AssetId,
            Timestamp = data.Timestamp,
            Type = data.Type,
            Metrics = data.Metrics,
            Source = data.Source,
            DataType = "telemetry",
            TTL = (int)DateTimeOffset.UtcNow.AddDays(30).ToUnixTimeSeconds() // 30 day retention
        };

        await _dynamoDbContext.SaveAsync(record);

        // Publish event for downstream processing
        await _eventPublisher.PublishTelemetryReceivedEvent(data);
    }

    public async Task ProcessBatchAsync(IEnumerable<TelemetryData> batch)
    {
        var batchWrite = _dynamoDbContext.CreateBatchWrite<TelemetryRecord>();
        
        foreach (var data in batch)
        {
            var record = new TelemetryRecord
            {
                PartitionKey = $"{data.AssetId}#{data.Timestamp:yyyy-MM-dd}",
                SortKey = data.Timestamp.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
                AssetId = data.AssetId,
                Timestamp = data.Timestamp,
                Type = data.Type,
                Metrics = data.Metrics,
                Source = data.Source,
                DataType = "telemetry",
                TTL = (int)DateTimeOffset.UtcNow.AddDays(30).ToUnixTimeSeconds()
            };
            batchWrite.AddPutItem(record);
        }

        await batchWrite.ExecuteAsync();

        // Publish events for each telemetry point
        foreach (var data in batch)
        {
            await _eventPublisher.PublishTelemetryReceivedEvent(data);
        }
    }
}

// Event Publisher
public class EventPublisher
{
    private readonly IAmazonSQS _sqsClient;
    private readonly string _queueUrl;
    private readonly ILogger<EventPublisher> _logger;

    public EventPublisher(IAmazonSQS sqsClient, IConfiguration configuration, ILogger<EventPublisher> logger)
    {
        _sqsClient = sqsClient;
        _queueUrl = configuration["AWS:SQS:TelemetryQueueUrl"];
        _logger = logger;
    }

    public async Task PublishTelemetryReceivedEvent(TelemetryData data)
    {
        var @event = new
        {
            EventType = "TelemetryReceived",
            AssetId = data.AssetId,
            Timestamp = data.Timestamp,
            Metrics = data.Metrics,
            Type = data.Type,
            Source = data.Source,
            EventId = Guid.NewGuid().ToString(),
            OccurredOn = DateTime.UtcNow
        };

        var json = JsonSerializer.Serialize(@event);
        var request = new SendMessageRequest
        {
            QueueUrl = _queueUrl,
            MessageBody = json,
            MessageAttributes = new Dictionary<string, MessageAttributeValue>
            {
                {
                    "EventType", new MessageAttributeValue
                    {
                        StringValue = "TelemetryReceived",
                        DataType = "String"
                    }
                }
            }
        };

        await _sqsClient.SendMessageAsync(request);
        _logger.LogInformation("Published TelemetryReceived event for asset {AssetId}", data.AssetId);
    }
}

// Health Checks
public class DynamoDbHealthCheck : IHealthCheck
{
    private readonly IAmazonDynamoDB _dynamoDb;

    public DynamoDbHealthCheck(IAmazonDynamoDB dynamoDb)
    {
        _dynamoDb = dynamoDb;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var request = new ListTablesRequest { Limit = 1 };
            await _dynamoDb.ListTablesAsync(request, cancellationToken);
            return HealthCheckResult.Healthy("DynamoDB connection successful");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("DynamoDB connection failed", ex);
        }
    }
}