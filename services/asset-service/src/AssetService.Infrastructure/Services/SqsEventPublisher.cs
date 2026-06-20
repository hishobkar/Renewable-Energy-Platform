using Amazon.SQS;
using Amazon.SQS.Model;
using Application.Interfaces;
using Domain.Common;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace Infrastructure.Services;

public class SqsEventPublisher : IEventPublisher
{
    private readonly IAmazonSQS _sqsClient;
    private readonly string _queueUrl;
    private readonly ILogger<SqsEventPublisher> _logger;

    public SqsEventPublisher(IAmazonSQS sqsClient, IConfiguration configuration, ILogger<SqsEventPublisher> logger)
    {
        _sqsClient = sqsClient;
        _queueUrl = configuration["Sqs:QueueUrl"] ?? "http://localhost:4566/000000000000/telemetry-events";
        _logger = logger;
    }

    public async Task PublishAsync(DomainEvent domainEvent, CancellationToken cancellationToken)
    {
        try
        {
            var message = JsonSerializer.Serialize(domainEvent, domainEvent.GetType());
            var request = new SendMessageRequest
            {
                QueueUrl = _queueUrl,
                MessageBody = message,
                MessageAttributes = new Dictionary<string, MessageAttributeValue>
                {
                    ["EventType"] = new MessageAttributeValue
                    {
                        DataType = "String",
                        StringValue = domainEvent.GetType().Name
                    }
                }
            };

            await _sqsClient.SendMessageAsync(request, cancellationToken);
            _logger.LogInformation("Published event {EventType} to SQS", domainEvent.GetType().Name);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish event {EventType}", domainEvent.GetType().Name);
        }
    }
}
