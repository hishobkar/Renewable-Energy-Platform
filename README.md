# Smart Renewable Energy Monitoring Platform

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/your-repo)
[![Coverage](https://img.shields.io/badge/coverage-85%25-brightgreen)](https://github.com/your-repo)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

## Overview

The Smart Renewable Energy Monitoring Platform is an enterprise-grade microservices system designed to monitor, analyze, and manage renewable energy assets including wind turbines and solar farms. The platform leverages event-driven architecture, CQRS, and Domain-Driven Design (DDD) to provide real-time telemetry processing, anomaly detection, and automated alerting.

### Key Features

- **Asset Management**: Register, track, and manage renewable energy assets
- **Real-time Telemetry**: Collect and process telemetry data from IoT sensors
- **Anomaly Detection**: ML-powered anomaly detection using Isolation Forest
- **Maintenance Management**: Track work orders and maintenance schedules
- **Alert System**: Multi-channel alerts (Email, SMS, Slack, PagerDuty)
- **Full Observability**: OpenTelemetry, distributed tracing, and metrics
- **Event-Driven Architecture**: SQS, SNS, and EventBridge integration
- **CQRS & DDD**: Clean separation of commands and queries

## Architecture

### Microservices

| Service | Technology | Database | Responsibilities |
|---------|-----------|----------|------------------|
| Asset Service | ASP.NET Core 9 Controller API | Aurora PostgreSQL | Asset registration, status management |
| Telemetry Service | ASP.NET Core 9 Minimal API | DynamoDB | Telemetry ingestion, event publishing |
| Anomaly Detection | Python FastAPI | DynamoDB | ML-based anomaly detection |
| Maintenance Service | ASP.NET Core Controller API | Aurora PostgreSQL | Work orders, maintenance tasks |
| Alert Service | Python FastAPI | DynamoDB | Alert generation, multi-channel notifications |

### Technology Stack

- **Backend**: ASP.NET Core 9, Python 3.11, FastAPI
- **Databases**: Aurora PostgreSQL, DynamoDB
- **Messaging**: SQS, SNS, EventBridge
- **Containerization**: Docker, Kubernetes (EKS)
- **Orchestration**: ECS Fargate, EKS
- **CI/CD**: CodePipeline, CodeBuild
- **Monitoring**: CloudWatch, Prometheus, Grafana
- **Tracing**: AWS X-Ray, Jaeger, OpenTelemetry
- **Security**: JWT, IAM, Secrets Manager

## Prerequisites

- Docker Desktop 4.0+
- kubectl 1.25+
- Helm 3.0+
- Terraform 1.0+
- AWS CLI 2.0+
- .NET 9 SDK
- Python 3.11+

## Quick Start (Local Development)

1. **Clone the repository**
```bash
git clone https://github.com/your-repo/renewable-energy-platform.git
cd renewable-energy-platform
```




### Project Structure

```
smart-renewable-energy-platform/
│
├── services/
│   ├── asset-service/
│   │   ├── src/
│   │   │   ├── AssetService.API/
│   │   │   │   ├── Controllers/
│   │   │   │   │   ├── AssetController.cs
│   │   │   │   │   ├── HealthController.cs
│   │   │   │   │   └── MetricsController.cs
│   │   │   │   ├── Middleware/
│   │   │   │   │   ├── ExceptionHandlingMiddleware.cs
│   │   │   │   │   ├── CorrelationIdMiddleware.cs
│   │   │   │   │   └── RequestLoggingMiddleware.cs
│   │   │   │   ├── Filters/
│   │   │   │   │   ├── ValidationFilter.cs
│   │   │   │   │   └── ApiKeyAuthFilter.cs
│   │   │   │   ├── Validators/
│   │   │   │   │   ├── RegisterAssetValidator.cs
│   │   │   │   │   └── UpdateAssetValidator.cs
│   │   │   │   ├── Program.cs
│   │   │   │   ├── Startup.cs
│   │   │   │   ├── appsettings.json
│   │   │   │   ├── appsettings.Development.json
│   │   │   │   ├── appsettings.Production.json
│   │   │   │   └── AssetService.API.csproj
│   │   │   │
│   │   │   ├── AssetService.Application/
│   │   │   │   ├── Commands/
│   │   │   │   │   ├── RegisterAsset/
│   │   │   │   │   │   ├── RegisterAssetCommand.cs
│   │   │   │   │   │   ├── RegisterAssetHandler.cs
│   │   │   │   │   │   ├── RegisterAssetValidator.cs
│   │   │   │   │   │   └── RegisterAssetResponse.cs
│   │   │   │   │   ├── UpdateAssetStatus/
│   │   │   │   │   │   ├── UpdateAssetStatusCommand.cs
│   │   │   │   │   │   ├── UpdateAssetStatusHandler.cs
│   │   │   │   │   │   └── UpdateAssetStatusValidator.cs
│   │   │   │   │   ├── ScheduleMaintenance/
│   │   │   │   │   │   ├── ScheduleMaintenanceCommand.cs
│   │   │   │   │   │   └── ScheduleMaintenanceHandler.cs
│   │   │   │   │   └── DeleteAsset/
│   │   │   │   │       ├── DeleteAssetCommand.cs
│   │   │   │   │       └── DeleteAssetHandler.cs
│   │   │   │   │
│   │   │   │   ├── Queries/
│   │   │   │   │   ├── GetAssetDetails/
│   │   │   │   │   │   ├── GetAssetQuery.cs
│   │   │   │   │   │   ├── GetAssetHandler.cs
│   │   │   │   │   │   └── AssetDetailDto.cs
│   │   │   │   │   ├── ListAssets/
│   │   │   │   │   │   ├── ListAssetsQuery.cs
│   │   │   │   │   │   ├── ListAssetsHandler.cs
│   │   │   │   │   │   ├── AssetFilter.cs
│   │   │   │   │   │   └── AssetListDto.cs
│   │   │   │   │   ├── GetAssetTelemetry/
│   │   │   │   │   │   ├── GetAssetTelemetryQuery.cs
│   │   │   │   │   │   └── GetAssetTelemetryHandler.cs
│   │   │   │   │   └── GetAssetMaintenanceHistory/
│   │   │   │   │       ├── GetAssetMaintenanceHistoryQuery.cs
│   │   │   │   │       └── GetAssetMaintenanceHistoryHandler.cs
│   │   │   │   │
│   │   │   │   ├── DTOs/
│   │   │   │   │   ├── AssetDto.cs
│   │   │   │   │   ├── AssetDetailDto.cs
│   │   │   │   │   ├── AssetTelemetryDto.cs
│   │   │   │   │   └── AssetMaintenanceDto.cs
│   │   │   │   │
│   │   │   │   ├── Interfaces/
│   │   │   │   │   ├── IAssetService.cs
│   │   │   │   │   ├── IAssetRepository.cs
│   │   │   │   │   ├── IEventPublisher.cs
│   │   │   │   │   └── ICacheService.cs
│   │   │   │   │
│   │   │   │   ├── Mappings/
│   │   │   │   │   ├── AssetMappingProfile.cs
│   │   │   │   │   └── MaintenanceMappingProfile.cs
│   │   │   │   │
│   │   │   │   ├── Behaviors/
│   │   │   │   │   ├── LoggingBehavior.cs
│   │   │   │   │   ├── ValidationBehavior.cs
│   │   │   │   │   └── PerformanceBehavior.cs
│   │   │   │   │
│   │   │   │   ├── Exceptions/
│   │   │   │   │   ├── NotFoundException.cs
│   │   │   │   │   ├── ValidationException.cs
│   │   │   │   │   ├── BusinessRuleException.cs
│   │   │   │   │   └── ConflictException.cs
│   │   │   │   │
│   │   │   │   ├── Constants/
│   │   │   │   │   ├── ErrorCodes.cs
│   │   │   │   │   ├── CacheKeys.cs
│   │   │   │   │   └── EventTypes.cs
│   │   │   │   │
│   │   │   │   └── AssetService.Application.csproj
│   │   │   │
│   │   │   ├── AssetService.Domain/
│   │   │   │   ├── Entities/
│   │   │   │   │   ├── Asset.cs
│   │   │   │   │   ├── AssetType.cs
│   │   │   │   │   ├── AssetStatus.cs
│   │   │   │   │   ├── MaintenanceSchedule.cs
│   │   │   │   │   └── TelemetryData.cs
│   │   │   │   │
│   │   │   │   ├── ValueObjects/
│   │   │   │   │   ├── GeographicLocation.cs
│   │   │   │   │   ├── Capacity.cs
│   │   │   │   │   ├── Address.cs
│   │   │   │   │   └── ContactInfo.cs
│   │   │   │   │
│   │   │   │   ├── Events/
│   │   │   │   │   ├── AssetRegisteredEvent.cs
│   │   │   │   │   ├── AssetStatusChangedEvent.cs
│   │   │   │   │   ├── MaintenanceScheduledEvent.cs
│   │   │   │   │   ├── MaintenancePerformedEvent.cs
│   │   │   │   │   └── TelemetryReceivedEvent.cs
│   │   │   │   │
│   │   │   │   ├── Aggregates/
│   │   │   │   │   └── AssetAggregate.cs
│   │   │   │   │
│   │   │   │   ├── Repositories/
│   │   │   │   │   ├── IAssetRepository.cs
│   │   │   │   │   └── IMaintenanceRepository.cs
│   │   │   │   │
│   │   │   │   ├── Services/
│   │   │   │   │   ├── IDomainEventService.cs
│   │   │   │   │   └── IAssetValidationService.cs
│   │   │   │   │
│   │   │   │   ├── Specifications/
│   │   │   │   │   ├── AssetSpecification.cs
│   │   │   │   │   ├── AssetByTypeSpecification.cs
│   │   │   │   │   └── AssetByStatusSpecification.cs
│   │   │   │   │
│   │   │   │   ├── Factories/
│   │   │   │   │   └── AssetFactory.cs
│   │   │   │   │
│   │   │   │   └── AssetService.Domain.csproj
│   │   │   │
│   │   │   ├── AssetService.Infrastructure/
│   │   │   │   ├── Data/
│   │   │   │   │   ├── Context/
│   │   │   │   │   │   └── ApplicationDbContext.cs
│   │   │   │   │   ├── Configurations/
│   │   │   │   │   │   ├── AssetConfiguration.cs
│   │   │   │   │   │   ├── MaintenanceScheduleConfiguration.cs
│   │   │   │   │   │   └── TelemetryDataConfiguration.cs
│   │   │   │   │   ├── Migrations/
│   │   │   │   │   │   ├── 20240101000000_InitialCreate.cs
│   │   │   │   │   │   ├── 20240115000000_AddMaintenanceSchedule.cs
│   │   │   │   │   │   └── 20240201000000_AddTelemetryData.cs
│   │   │   │   │   ├── SeedData/
│   │   │   │   │   │   └── DatabaseSeeder.cs
│   │   │   │   │   └── Extensions/
│   │   │   │   │       └── ModelBuilderExtensions.cs
│   │   │   │   │
│   │   │   │   ├── Repositories/
│   │   │   │   │   ├── AssetRepository.cs
│   │   │   │   │   ├── MaintenanceRepository.cs
│   │   │   │   │   ├── UnitOfWork.cs
│   │   │   │   │   └── BaseRepository.cs
│   │   │   │   │
│   │   │   │   ├── Services/
│   │   │   │   │   ├── EventPublisher.cs
│   │   │   │   │   ├── CacheService.cs
│   │   │   │   │   ├── DomainEventService.cs
│   │   │   │   │   └── AssetValidationService.cs
│   │   │   │   │
│   │   │   │   ├── Messaging/
│   │   │   │   │   ├── SqsEventPublisher.cs
│   │   │   │   │   ├── SnsEventPublisher.cs
│   │   │   │   │   └── EventBridgePublisher.cs
│   │   │   │   │
│   │   │   │   ├── Cache/
│   │   │   │   │   ├── RedisCacheService.cs
│   │   │   │   │   └── MemoryCacheService.cs
│   │   │   │   │
│   │   │   │   ├── Logging/
│   │   │   │   │   ├── SerilogConfigurator.cs
│   │   │   │   │   └── CloudWatchLogger.cs
│   │   │   │   │
│   │   │   │   ├── HealthChecks/
│   │   │   │   │   ├── DatabaseHealthCheck.cs
│   │   │   │   │   ├── RedisHealthCheck.cs
│   │   │   │   │   ├── SqsHealthCheck.cs
│   │   │   │   │   └── SnsHealthCheck.cs
│   │   │   │   │
│   │   │   │   ├── Extensions/
│   │   │   │   │   ├── ServiceCollectionExtensions.cs
│   │   │   │   │   └── ApplicationBuilderExtensions.cs
│   │   │   │   │
│   │   │   │   ├── Constants/
│   │   │   │   │   └── InfrastructureConstants.cs
│   │   │   │   │
│   │   │   │   └── AssetService.Infrastructure.csproj
│   │   │   │
│   │   │   └── AssetService.Shared/
│   │   │       ├── Common/
│   │   │       │   ├── BaseEntity.cs
│   │   │       │   ├── ValueObject.cs
│   │   │       │   └── AggregateRoot.cs
│   │   │       │
│   │   │       ├── Extensions/
│   │   │       │   ├── StringExtensions.cs
│   │   │       │   ├── DateTimeExtensions.cs
│   │   │       │   └── EnumExtensions.cs
│   │   │       │
│   │   │       ├── Helpers/
│   │   │       │   ├── IdGenerator.cs
│   │   │       │   ├── JsonHelper.cs
│   │   │       │   └── EncryptionHelper.cs
│   │   │       │
│   │   │       ├── Attributes/
│   │   │       │   ├── SwaggerOperationAttribute.cs
│   │   │       │   └── ValidateAttribute.cs
│   │   │       │
│   │   │       ├── Responses/
│   │   │       │   ├── ApiResponse.cs
│   │   │       │   ├── PagedResponse.cs
│   │   │       │   └── ErrorResponse.cs
│   │   │       │
│   │   │       └── AssetService.Shared.csproj
│   │   │
│   │   ├── tests/
│   │   │   ├── AssetService.UnitTests/
│   │   │   │   ├── Application/
│   │   │   │   │   ├── Commands/
│   │   │   │   │   │   ├── RegisterAssetHandlerTests.cs
│   │   │   │   │   │   └── UpdateAssetStatusHandlerTests.cs
│   │   │   │   │   └── Queries/
│   │   │   │   │       ├── GetAssetHandlerTests.cs
│   │   │   │   │       └── ListAssetsHandlerTests.cs
│   │   │   │   │
│   │   │   │   ├── Domain/
│   │   │   │   │   ├── AssetTests.cs
│   │   │   │   │   └── ValueObjectsTests.cs
│   │   │   │   │
│   │   │   │   ├── Infrastructure/
│   │   │   │   │   ├── AssetRepositoryTests.cs
│   │   │   │   │   └── EventPublisherTests.cs
│   │   │   │   │
│   │   │   │   ├── Controllers/
│   │   │   │   │   └── AssetControllerTests.cs
│   │   │   │   │
│   │   │   │   ├── Fixtures/
│   │   │   │   │   ├── AssetFixture.cs
│   │   │   │   │   └── DatabaseFixture.cs
│   │   │   │   │
│   │   │   │   ├── Mocks/
│   │   │   │   │   ├── MockAssetRepository.cs
│   │   │   │   │   └── MockEventPublisher.cs
│   │   │   │   │
│   │   │   │   ├── Helpers/
│   │   │   │   │   └── TestDataGenerator.cs
│   │   │   │   │
│   │   │   │   └── AssetService.UnitTests.csproj
│   │   │   │
│   │   │   ├── AssetService.IntegrationTests/
│   │   │   │   ├── Api/
│   │   │   │   │   ├── AssetControllerIntegrationTests.cs
│   │   │   │   │   └── HealthControllerIntegrationTests.cs
│   │   │   │   │
│   │   │   │   ├── Database/
│   │   │   │   │   └── RepositoryIntegrationTests.cs
│   │   │   │   │
│   │   │   │   ├── Messaging/
│   │   │   │   │   └── EventPublisherIntegrationTests.cs
│   │   │   │   │
│   │   │   │   ├── Factories/
│   │   │   │   │   └── CustomWebApplicationFactory.cs
│   │   │   │   │
│   │   │   │   └── AssetService.IntegrationTests.csproj
│   │   │   │
│   │   │   └── AssetService.LoadTests/
│   │   │       ├── Scenarios/
│   │   │       │   ├── AssetRegistrationScenario.cs
│   │   │       │   └── AssetQueryScenario.cs
│   │   │       │
│   │   │       ├── Config/
│   │   │       │   └── LoadTestConfig.json
│   │   │       │
│   │   │       └── AssetService.LoadTests.csproj
│   │   │
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── .dockerignore
│   │   ├── appsettings.json
│   │   ├── appsettings.Development.json
│   │   ├── appsettings.Production.json
│   │   ├── launchSettings.json
│   │   ├── AssetService.sln
│   │   └── README.md
│   │
│   ├── telemetry-service/
│   │   ├── src/
│   │   │   ├── TelemetryService.API/
│   │   │   │   ├── Endpoints/
│   │   │   │   │   ├── TelemetryEndpoints.cs
│   │   │   │   │   ├── HealthEndpoints.cs
│   │   │   │   │   └── MetricsEndpoints.cs
│   │   │   │   │
│   │   │   │   ├── Middleware/
│   │   │   │   │   ├── ExceptionHandlingMiddleware.cs
│   │   │   │   │   └── RequestLoggingMiddleware.cs
│   │   │   │   │
│   │   │   │   ├── Validators/
│   │   │   │   │   ├── TelemetryDataValidator.cs
│   │   │   │   │   └── BatchTelemetryValidator.cs
│   │   │   │   │
│   │   │   │   ├── Program.cs
│   │   │   │   ├── Startup.cs
│   │   │   │   ├── appsettings.json
│   │   │   │   ├── appsettings.Development.json
│   │   │   │   └── appsettings.Production.json
│   │   │   │
│   │   │   ├── TelemetryService.Application/
│   │   │   │   ├── Handlers/
│   │   │   │   │   ├── ProcessTelemetryHandler.cs
│   │   │   │   │   ├── ProcessBatchTelemetryHandler.cs
│   │   │   │   │   └── QueryTelemetryHandler.cs
│   │   │   │   │
│   │   │   │   ├── DTOs/
│   │   │   │   │   ├── TelemetryDataDto.cs
│   │   │   │   │   ├── TelemetryBatchDto.cs
│   │   │   │   │   └── TelemetryQueryDto.cs
│   │   │   │   │
│   │   │   │   ├── Interfaces/
│   │   │   │   │   ├── ITelemetryProcessor.cs
│   │   │   │   │   ├── ITelemetryRepository.cs
│   │   │   │   │   └── IEventPublisher.cs
│   │   │   │   │
│   │   │   │   ├── Mappings/
│   │   │   │   │   └── TelemetryMappingProfile.cs
│   │   │   │   │
│   │   │   │   ├── Constants/
│   │   │   │   │   ├── TelemetryTypes.cs
│   │   │   │   │   └── MetricNames.cs
│   │   │   │   │
│   │   │   │   └── TelemetryService.Application.csproj
│   │   │   │
│   │   │   ├── TelemetryService.Domain/
│   │   │   │   ├── Entities/
│   │   │   │   │   ├── TelemetryRecord.cs
│   │   │   │   │   ├── TelemetryAggregate.cs
│   │   │   │   │   └── TelemetrySummary.cs
│   │   │   │   │
│   │   │   │   ├── ValueObjects/
│   │   │   │   │   ├── TelemetryMetric.cs
│   │   │   │   │   ├── TimestampRange.cs
│   │   │   │   │   └── DataQuality.cs
│   │   │   │   │
│   │   │   │   ├── Events/
│   │   │   │   │   ├── TelemetryReceivedEvent.cs
│   │   │   │   │   ├── TelemetryBatchReceivedEvent.cs
│   │   │   │   │   └── TelemetryValidationFailedEvent.cs
│   │   │   │   │
│   │   │   │   ├── Enums/
│   │   │   │   │   ├── TelemetrySource.cs
│   │   │   │   │   ├── DataType.cs
│   │   │   │   │   └── ProcessingStatus.cs
│   │   │   │   │
│   │   │   │   ├── Repositories/
│   │   │   │   │   └── ITelemetryRepository.cs
│   │   │   │   │
│   │   │   │   └── TelemetryService.Domain.csproj
│   │   │   │
│   │   │   ├── TelemetryService.Infrastructure/
│   │   │   │   ├── Data/
│   │   │   │   │   ├── DynamoDB/
│   │   │   │   │   │   ├── TelemetryDbContext.cs
│   │   │   │   │   │   ├── DynamoDBConfiguration.cs
│   │   │   │   │   │   └── DynamoDBInitializer.cs
│   │   │   │   │   │
│   │   │   │   │   └── Repositories/
│   │   │   │   │       ├── TelemetryRepository.cs
│   │   │   │   │       └── TelemetrySummaryRepository.cs
│   │   │   │   │
│   │   │   │   ├── Services/
│   │   │   │   │   ├── TelemetryProcessor.cs
│   │   │   │   │   ├── TelemetryValidator.cs
│   │   │   │   │   └── TelemetryEnricher.cs
│   │   │   │   │
│   │   │   │   ├── Messaging/
│   │   │   │   │   ├── SqsEventPublisher.cs
│   │   │   │   │   ├── SnsEventPublisher.cs
│   │   │   │   │   └── KinesisEventPublisher.cs
│   │   │   │   │
│   │   │   │   ├── Cache/
│   │   │   │   │   ├── TelemetryCacheService.cs
│   │   │   │   │   └── CacheInvalidationService.cs
│   │   │   │   │
│   │   │   │   ├── HealthChecks/
│   │   │   │   │   ├── DynamoDbHealthCheck.cs
│   │   │   │   │   ├── SqsHealthCheck.cs
│   │   │   │   │   └── RedisHealthCheck.cs
│   │   │   │   │
│   │   │   │   ├── Extensions/
│   │   │   │   │   └── ServiceCollectionExtensions.cs
│   │   │   │   │
│   │   │   │   └── TelemetryService.Infrastructure.csproj
│   │   │   │
│   │   │   └── TelemetryService.Shared/
│   │   │       ├── Common/
│   │   │       │   ├── BaseEntity.cs
│   │   │       │   └── ValueObject.cs
│   │   │       │
│   │   │       ├── Helpers/
│   │   │       │   ├── TimestampHelper.cs
│   │   │       │   └── MetricHelper.cs
│   │   │       │
│   │   │       ├── Extensions/
│   │   │       │   ├── DictionaryExtensions.cs
│   │   │       │   └── DoubleExtensions.cs
│   │   │       │
│   │   │       └── TelemetryService.Shared.csproj
│   │   │
│   │   ├── tests/
│   │   │   ├── TelemetryService.UnitTests/
│   │   │   │   ├── Application/
│   │   │   │   │   ├── ProcessTelemetryHandlerTests.cs
│   │   │   │   │   └── QueryTelemetryHandlerTests.cs
│   │   │   │   │
│   │   │   │   ├── Domain/
│   │   │   │   │   ├── TelemetryRecordTests.cs
│   │   │   │   │   └── TelemetryMetricTests.cs
│   │   │   │   │
│   │   │   │   ├── Infrastructure/
│   │   │   │   │   ├── TelemetryRepositoryTests.cs
│   │   │   │   │   └── TelemetryProcessorTests.cs
│   │   │   │   │
│   │   │   │   ├── Endpoints/
│   │   │   │   │   └── TelemetryEndpointsTests.cs
│   │   │   │   │
│   │   │   │   ├── Fixtures/
│   │   │   │   │   ├── TelemetryFixture.cs
│   │   │   │   │   └── DynamoDbFixture.cs
│   │   │   │   │
│   │   │   │   └── TelemetryService.UnitTests.csproj
│   │   │   │
│   │   │   └── TelemetryService.IntegrationTests/
│   │   │       ├── Api/
│   │   │       │   └── TelemetryApiIntegrationTests.cs
│   │   │       │
│   │   │       ├── Database/
│   │   │       │   └── DynamoDbIntegrationTests.cs
│   │   │       │
│   │   │       ├── Messaging/
│   │   │       │   └── EventPublishingIntegrationTests.cs
│   │   │       │
│   │   │       ├── Factories/
│   │   │       │   └── CustomWebApplicationFactory.cs
│   │   │       │
│   │   │       └── TelemetryService.IntegrationTests.csproj
│   │   │
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── .dockerignore
│   │   ├── appsettings.json
│   │   ├── appsettings.Development.json
│   │   ├── appsettings.Production.json
│   │   ├── launchSettings.json
│   │   ├── TelemetryService.sln
│   │   └── README.md
│   │
│   ├── anomaly-detection-service/
│   │   ├── src/
│   │   │   ├── api/
│   │   │   │   ├── routes/
│   │   │   │   │   ├── detection.py
│   │   │   │   │   ├── anomalies.py
│   │   │   │   │   ├── models.py
│   │   │   │   │   └── health.py
│   │   │   │   │
│   │   │   │   ├── dependencies/
│   │   │   │   │   ├── auth.py
│   │   │   │   │   ├── database.py
│   │   │   │   │   └── services.py
│   │   │   │   │
│   │   │   │   ├── middleware/
│   │   │   │   │   ├── logging.py
│   │   │   │   │   ├── correlation_id.py
│   │   │   │   │   └── error_handler.py
│   │   │   │   │
│   │   │   │   ├── models/
│   │   │   │   │   ├── requests.py
│   │   │   │   │   ├── responses.py
│   │   │   │   │   └── domain.py
│   │   │   │   │
│   │   │   │   ├── schemas/
│   │   │   │   │   ├── anomaly.py
│   │   │   │   │   ├── telemetry.py
│   │   │   │   │   └── detection.py
│   │   │   │   │
│   │   │   │   ├── validators/
│   │   │   │   │   ├── telemetry_validator.py
│   │   │   │   │   └── anomaly_validator.py
│   │   │   │   │
│   │   │   │   └── __init__.py
│   │   │   │
│   │   │   ├── core/
│   │   │   │   ├── detectors/
│   │   │   │   │   ├── base_detector.py
│   │   │   │   │   ├── isolation_forest_detector.py
│   │   │   │   │   ├── statistical_detector.py
│   │   │   │   │   └── ensemble_detector.py
│   │   │   │   │
│   │   │   │   ├── models/
│   │   │   │   │   ├── anomaly_model.py
│   │   │   │   │   ├── model_manager.py
│   │   │   │   │   └── model_persistence.py
│   │   │   │   │
│   │   │   │   ├── processors/
│   │   │   │   │   ├── data_processor.py
│   │   │   │   │   ├── feature_engineer.py
│   │   │   │   │   └── normalizer.py
│   │   │   │   │
│   │   │   │   ├── services/
│   │   │   │   │   ├── anomaly_service.py
│   │   │   │   │   ├── detection_service.py
│   │   │   │   │   └── training_service.py
│   │   │   │   │
│   │   │   │   ├── analyzers/
│   │   │   │   │   ├── pattern_analyzer.py
│   │   │   │   │   ├── trend_analyzer.py
│   │   │   │   │   └── correlation_analyzer.py
│   │   │   │   │
│   │   │   │   ├── rules/
│   │   │   │   │   ├── rule_engine.py
│   │   │   │   │   ├── static_rules.py
│   │   │   │   │   └── dynamic_rules.py
│   │   │   │   │
│   │   │   │   └── __init__.py
│   │   │   │
│   │   │   ├── infrastructure/
│   │   │   │   ├── database/
│   │   │   │   │   ├── dynamodb/
│   │   │   │   │   │   ├── anomaly_repository.py
│   │   │   │   │   │   └── model_repository.py
│   │   │   │   │   │
│   │   │   │   │   └── postgres/
│   │   │   │   │       └── rule_repository.py
│   │   │   │   │
│   │   │   │   ├── messaging/
│   │   │   │   │   ├── sqs_consumer.py
│   │   │   │   │   ├── sns_publisher.py
│   │   │   │   │   └── event_bus.py
│   │   │   │   │
│   │   │   │   ├── cache/
│   │   │   │   │   ├── redis_cache.py
│   │   │   │   │   └── model_cache.py
│   │   │   │   │
│   │   │   │   ├── storage/
│   │   │   │   │   ├── s3_storage.py
│   │   │   │   │   └── model_storage.py
│   │   │   │   │
│   │   │   │   ├── monitoring/
│   │   │   │   │   ├── telemetry.py
│   │   │   │   │   ├── metrics.py
│   │   │   │   │   └── health.py
│   │   │   │   │
│   │   │   │   ├── config/
│   │   │   │   │   ├── settings.py
│   │   │   │   │   ├── logging_config.py
│   │   │   │   │   └── aws_config.py
│   │   │   │   │
│   │   │   │   └── __init__.py
│   │   │   │
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── anomaly.py
│   │   │   │   │   ├── detection_result.py
│   │   │   │   │   └── model_metadata.py
│   │   │   │   │
│   │   │   │   ├── value_objects/
│   │   │   │   │   ├── anomaly_score.py
│   │   │   │   │   ├── threshold.py
│   │   │   │   │   └── severity.py
│   │   │   │   │
│   │   │   │   ├── events/
│   │   │   │   │   ├── anomaly_detected_event.py
│   │   │   │   │   └── model_updated_event.py
│   │   │   │   │
│   │   │   │   ├── enums/
│   │   │   │   │   ├── anomaly_type.py
│   │   │   │   │   └── detection_status.py
│   │   │   │   │
│   │   │   │   └── __init__.py
│   │   │   │
│   │   │   ├── utils/
│   │   │   │   ├── logger.py
│   │   │   │   ├── validators.py
│   │   │   │   ├── decorators.py
│   │   │   │   ├── context.py
│   │   │   │   └── helpers.py
│   │   │   │
│   │   │   └── main.py
│   │   │
│   │   ├── tests/
│   │   │   ├── unit/
│   │   │   │   ├── core/
│   │   │   │   │   ├── test_detectors.py
│   │   │   │   │   ├── test_processors.py
│   │   │   │   │   └── test_services.py
│   │   │   │   │
│   │   │   │   ├── domain/
│   │   │   │   │   ├── test_anomaly.py
│   │   │   │   │   └── test_value_objects.py
│   │   │   │   │
│   │   │   │   ├── infrastructure/
│   │   │   │   │   ├── test_repositories.py
│   │   │   │   │   └── test_messaging.py
│   │   │   │   │
│   │   │   │   ├── api/
│   │   │   │   │   ├── test_detection.py
│   │   │   │   │   └── test_anomalies.py
│   │   │   │   │
│   │   │   │   ├── fixtures/
│   │   │   │   │   ├── data_fixtures.py
│   │   │   │   │   └── model_fixtures.py
│   │   │   │   │
│   │   │   │   └── conftest.py
│   │   │   │
│   │   │   ├── integration/
│   │   │   │   ├── test_dynamodb.py
│   │   │   │   ├── test_sqs.py
│   │   │   │   ├── test_sns.py
│   │   │   │   ├── test_detection_pipeline.py
│   │   │   │   └── conftest.py
│   │   │   │
│   │   │   └── e2e/
│   │   │       ├── test_end_to_end.py
│   │   │       └── test_scenarios.py
│   │   │
│   │   ├── scripts/
│   │   │   ├── train_models.py
│   │   │   ├── evaluate_models.py
│   │   │   └── generate_test_data.py
│   │   │
│   │   ├── notebooks/
│   │   │   ├── model_experimentation.ipynb
│   │   │   ├── data_exploration.ipynb
│   │   │   └── feature_analysis.ipynb
│   │   │
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── isolation_forest/
│   │   │   │   └── ensemble/
│   │   │   └── samples/
│   │   │       └── telemetry_sample.json
│   │   │
│   │   ├── requirements.txt
│   │   ├── requirements-dev.txt
│   │   ├── setup.py
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── .dockerignore
│   │   ├── .env.example
│   │   ├── .flake8
│   │   ├── .pylintrc
│   │   ├── pytest.ini
│   │   └── README.md
│   │
│   ├── maintenance-service/
│   │   ├── src/
│   │   │   ├── MaintenanceService.API/
│   │   │   │   ├── Controllers/
│   │   │   │   │   ├── MaintenanceController.cs
│   │   │   │   │   ├── WorkOrderController.cs
│   │   │   │   │   ├── ScheduleController.cs
│   │   │   │   │   └── HealthController.cs
│   │   │   │   │
│   │   │   │   ├── Middleware/
│   │   │   │   │   ├── ExceptionHandlingMiddleware.cs
│   │   │   │   │   └── AuthorizationMiddleware.cs
│   │   │   │   │
│   │   │   │   ├── Filters/
│   │   │   │   │   ├── ValidationFilter.cs
│   │   │   │   │   └── MaintenanceFilter.cs
│   │   │   │   │
│   │   │   │   ├── Validators/
│   │   │   │   │   ├── CreateMaintenanceTaskValidator.cs
│   │   │   │   │   ├── UpdateMaintenanceTaskValidator.cs
│   │   │   │   │   └── CreateWorkOrderValidator.cs
│   │   │   │   │
│   │   │   │   ├── Program.cs
│   │   │   │   ├── Startup.cs
│   │   │   │   ├── appsettings.json
│   │   │   │   ├── appsettings.Development.json
│   │   │   │   ├── appsettings.Production.json
│   │   │   │   └── MaintenanceService.API.csproj
│   │   │   │
│   │   │   ├── MaintenanceService.Application/
│   │   │   │   ├── Commands/
│   │   │   │   │   ├── CreateMaintenanceTask/
│   │   │   │   │   │   ├── CreateMaintenanceTaskCommand.cs
│   │   │   │   │   │   ├── CreateMaintenanceTaskHandler.cs
│   │   │   │   │   │   └── CreateMaintenanceTaskValidator.cs
│   │   │   │   │   ├── UpdateMaintenanceTask/
│   │   │   │   │   │   ├── UpdateMaintenanceTaskCommand.cs
│   │   │   │   │   │   └── UpdateMaintenanceTaskHandler.cs
│   │   │   │   │   ├── StartMaintenance/
│   │   │   │   │   │   ├── StartMaintenanceCommand.cs
│   │   │   │   │   │   └── StartMaintenanceHandler.cs
│   │   │   │   │   ├── CompleteMaintenance/
│   │   │   │   │   │   ├── CompleteMaintenanceCommand.cs
│   │   │   │   │   │   └── CompleteMaintenanceHandler.cs
│   │   │   │   │   ├── CreateWorkOrder/
│   │   │   │   │   │   ├── CreateWorkOrderCommand.cs
│   │   │   │   │   │   └── CreateWorkOrderHandler.cs
│   │   │   │   │   └── CancelMaintenanceTask/
│   │   │   │   │       ├── CancelMaintenanceTaskCommand.cs
│   │   │   │   │       └── CancelMaintenanceTaskHandler.cs
│   │   │   │   │
│   │   │   │   ├── Queries/
│   │   │   │   │   ├── GetMaintenanceTask/
│   │   │   │   │   │   ├── GetMaintenanceTaskQuery.cs
│   │   │   │   │   │   └── GetMaintenanceTaskHandler.cs
│   │   │   │   │   ├── ListMaintenanceTasks/
│   │   │   │   │   │   ├── ListMaintenanceTasksQuery.cs
│   │   │   │   │   │   ├── ListMaintenanceTasksHandler.cs
│   │   │   │   │   │   └── MaintenanceFilter.cs
│   │   │   │   │   ├── GetAssetMaintenanceHistory/
│   │   │   │   │   │   ├── GetAssetMaintenanceHistoryQuery.cs
│   │   │   │   │   │   └── GetAssetMaintenanceHistoryHandler.cs
│   │   │   │   │   ├── GetWorkOrder/
│   │   │   │   │   │   ├── GetWorkOrderQuery.cs
│   │   │   │   │   │   └── GetWorkOrderHandler.cs
│   │   │   │   │   └── GetScheduledMaintenance/
│   │   │   │   │       ├── GetScheduledMaintenanceQuery.cs
│   │   │   │   │       └── GetScheduledMaintenanceHandler.cs
│   │   │   │   │
│   │   │   │   ├── DTOs/
│   │   │   │   │   ├── MaintenanceTaskDto.cs
│   │   │   │   │   ├── MaintenanceTaskDetailDto.cs
│   │   │   │   │   ├── WorkOrderDto.cs
│   │   │   │   │   ├── MaintenanceStepDto.cs
│   │   │   │   │   └── MaintenanceNoteDto.cs
│   │   │   │   │
│   │   │   │   ├── Interfaces/
│   │   │   │   │   ├── IMaintenanceService.cs
│   │   │   │   │   ├── IMaintenanceRepository.cs
│   │   │   │   │   ├── IWorkOrderRepository.cs
│   │   │   │   │   └── IScheduleService.cs
│   │   │   │   │
│   │   │   │   ├── Mappings/
│   │   │   │   │   ├── MaintenanceMappingProfile.cs
│   │   │   │   │   └── WorkOrderMappingProfile.cs
│   │   │   │   │
│   │   │   │   ├── Behaviors/
│   │   │   │   │   ├── AuthorizationBehavior.cs
│   │   │   │   │   └── TransactionBehavior.cs
│   │   │   │   │
│   │   │   │   ├── Exceptions/
│   │   │   │   │   ├── MaintenanceNotFoundException.cs
│   │   │   │   │   ├── SchedulingConflictException.cs
│   │   │   │   │   └── InvalidWorkOrderException.cs
│   │   │   │   │
│   │   │   │   └── MaintenanceService.Application.csproj
│   │   │   │
│   │   │   ├── MaintenanceService.Domain/
│   │   │   │   ├── Entities/
│   │   │   │   │   ├── MaintenanceTask.cs
│   │   │   │   │   ├── WorkOrder.cs
│   │   │   │   │   ├── MaintenanceStep.cs
│   │   │   │   │   ├── MaintenanceNote.cs
│   │   │   │   │   └── MaintenanceSchedule.cs
│   │   │   │   │
│   │   │   │   ├── ValueObjects/
│   │   │   │   │   ├── WorkOrderNumber.cs
│   │   │   │   │   ├── MaintenancePriority.cs
│   │   │   │   │   ├── MaintenanceType.cs
│   │   │   │   │   └── MaintenanceStatus.cs
│   │   │   │   │
│   │   │   │   ├── Events/
│   │   │   │   │   ├── MaintenanceTaskCreatedEvent.cs
│   │   │   │   │   ├── MaintenanceStartedEvent.cs
│   │   │   │   │   ├── MaintenanceCompletedEvent.cs
│   │   │   │   │   ├── MaintenanceTaskCancelledEvent.cs
│   │   │   │   │   └── WorkOrderGeneratedEvent.cs
│   │   │   │   │
│   │   │   │   ├── Aggregates/
│   │   │   │   │   └── MaintenanceAggregate.cs
│   │   │   │   │
│   │   │   │   ├── Repositories/
│   │   │   │   │   ├── IMaintenanceTaskRepository.cs
│   │   │   │   │   └── IWorkOrderRepository.cs
│   │   │   │   │
│   │   │   │   ├── Services/
│   │   │   │   │   ├── IMaintenanceValidationService.cs
│   │   │   │   │   └── ISchedulingService.cs
│   │   │   │   │
│   │   │   │   ├── Specifications/
│   │   │   │   │   ├── MaintenanceTaskSpecification.cs
│   │   │   │   │   └── MaintenanceByPrioritySpecification.cs
│   │   │   │   │
│   │   │   │   └── MaintenanceService.Domain.csproj
│   │   │   │
│   │   │   ├── MaintenanceService.Infrastructure/
│   │   │   │   ├── Data/
│   │   │   │   │   ├── Context/
│   │   │   │   │   │   └── MaintenanceDbContext.cs
│   │   │   │   │   ├── Configurations/
│   │   │   │   │   │   ├── MaintenanceTaskConfiguration.cs
│   │   │   │   │   │   ├── WorkOrderConfiguration.cs
│   │   │   │   │   │   └── MaintenanceStepConfiguration.cs
│   │   │   │   │   ├── Migrations/
│   │   │   │   │   │   ├── 20240101000000_InitialMaintenance.cs
│   │   │   │   │   │   └── 20240201000000_AddWorkOrders.cs
│   │   │   │   │   ├── SeedData/
│   │   │   │   │   │   └── MaintenanceSeeder.cs
│   │   │   │   │   └── Extensions/
│   │   │   │   │       └── ModelBuilderExtensions.cs
│   │   │   │   │
│   │   │   │   ├── Repositories/
│   │   │   │   │   ├── MaintenanceTaskRepository.cs
│   │   │   │   │   ├── WorkOrderRepository.cs
│   │   │   │   │   ├── MaintenanceScheduleRepository.cs
│   │   │   │   │   └── UnitOfWork.cs
│   │   │   │   │
│   │   │   │   ├── Services/
│   │   │   │   │   ├── SchedulingService.cs
│   │   │   │   │   ├── MaintenanceValidationService.cs
│   │   │   │   │   └── WorkOrderNumberGenerator.cs
│   │   │   │   │
│   │   │   │   ├── Messaging/
│   │   │   │   │   ├── SnsEventPublisher.cs
│   │   │   │   │   ├── SqsEventPublisher.cs
│   │   │   │   │   └── EventBridgePublisher.cs
│   │   │   │   │
│   │   │   │   ├── Cache/
│   │   │   │   │   ├── MaintenanceCacheService.cs
│   │   │   │   │   └── WorkOrderCacheService.cs
│   │   │   │   │
│   │   │   │   ├── HealthChecks/
│   │   │   │   │   ├── DatabaseHealthCheck.cs
│   │   │   │   │   ├── SqsHealthCheck.cs
│   │   │   │   │   └── RedisHealthCheck.cs
│   │   │   │   │
│   │   │   │   ├── Extensions/
│   │   │   │   │   └── ServiceCollectionExtensions.cs
│   │   │   │   │
│   │   │   │   └── MaintenanceService.Infrastructure.csproj
│   │   │   │
│   │   │   └── MaintenanceService.Shared/
│   │   │       ├── Common/
│   │   │       │   ├── BaseEntity.cs
│   │   │       │   └── ValueObject.cs
│   │   │       │
│   │   │       ├── Helpers/
│   │   │       │   ├── DateTimeHelper.cs
│   │   │       │   └── WorkOrderHelper.cs
│   │   │       │
│   │   │       ├── Extensions/
│   │   │       │   ├── DateTimeExtensions.cs
│   │   │       │   └── EnumExtensions.cs
│   │   │       │
│   │   │       └── MaintenanceService.Shared.csproj
│   │   │
│   │   ├── tests/
│   │   │   ├── MaintenanceService.UnitTests/
│   │   │   │   ├── Application/
│   │   │   │   │   ├── Commands/
│   │   │   │   │   │   ├── CreateMaintenanceTaskHandlerTests.cs
│   │   │   │   │   │   ├── StartMaintenanceHandlerTests.cs
│   │   │   │   │   │   └── CompleteMaintenanceHandlerTests.cs
│   │   │   │   │   └── Queries/
│   │   │   │   │       ├── GetMaintenanceTaskHandlerTests.cs
│   │   │   │   │       └── ListMaintenanceTasksHandlerTests.cs
│   │   │   │   │
│   │   │   │   ├── Domain/
│   │   │   │   │   ├── MaintenanceTaskTests.cs
│   │   │   │   │   └── WorkOrderTests.cs
│   │   │   │   │
│   │   │   │   ├── Infrastructure/
│   │   │   │   │   ├── MaintenanceRepositoryTests.cs
│   │   │   │   │   └── SchedulingServiceTests.cs
│   │   │   │   │
│   │   │   │   ├── Controllers/
│   │   │   │   │   └── MaintenanceControllerTests.cs
│   │   │   │   │
│   │   │   │   ├── Fixtures/
│   │   │   │   │   ├── MaintenanceFixture.cs
│   │   │   │   │   └── WorkOrderFixture.cs
│   │   │   │   │
│   │   │   │   └── MaintenanceService.UnitTests.csproj
│   │   │   │
│   │   │   └── MaintenanceService.IntegrationTests/
│   │   │       ├── Api/
│   │   │       │   └── MaintenanceControllerIntegrationTests.cs
│   │   │       │
│   │   │       ├── Database/
│   │   │       │   └── RepositoryIntegrationTests.cs
│   │   │       │
│   │   │       ├── Messaging/
│   │   │       │   └── EventPublishingIntegrationTests.cs
│   │   │       │
│   │   │       ├── Factories/
│   │   │       │   └── CustomWebApplicationFactory.cs
│   │   │       │
│   │   │       └── MaintenanceService.IntegrationTests.csproj
│   │   │
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── .dockerignore
│   │   ├── appsettings.json
│   │   ├── appsettings.Development.json
│   │   ├── appsettings.Production.json
│   │   ├── launchSettings.json
│   │   ├── MaintenanceService.sln
│   │   └── README.md
│   │
│   └── alert-service/
│       ├── src/
│       │   ├── api/
│       │   │   ├── routes/
│       │   │   │   ├── alerts.py
│       │   │   │   ├── notifications.py
│       │   │   │   ├── channels.py
│       │   │   │   └── health.py
│       │   │   │
│       │   │   ├── dependencies/
│       │   │   │   ├── auth.py
│       │   │   │   ├── database.py
│       │   │   │   └── services.py
│       │   │   │
│       │   │   ├── middleware/
│       │   │   │   ├── logging.py
│       │   │   │   ├── rate_limiter.py
│       │   │   │   └── error_handler.py
│       │   │   │
│       │   │   ├── models/
│       │   │   │   ├── requests.py
│       │   │   │   ├── responses.py
│       │   │   │   └── domain.py
│       │   │   │
│       │   │   ├── schemas/
│       │   │   │   ├── alert.py
│       │   │   │   ├── notification.py
│       │   │   │   └── channel.py
│       │   │   │
│       │   │   ├── validators/
│       │   │   │   ├── alert_validator.py
│       │   │   │   └── notification_validator.py
│       │   │   │
│       │   │   └── __init__.py
│       │   │
│       │   ├── core/
│       │   │   ├── services/
│       │   │   │   ├── alert_service.py
│       │   │   │   ├── notification_service.py
│       │   │   │   ├── channel_service.py
│       │   │   │   ├── escalation_service.py
│       │   │   │   └── suppression_service.py
│       │   │   │
│       │   │   ├── engines/
│       │   │   │   ├── notification_engine.py
│       │   │   │   ├── escalation_engine.py
│       │   │   │   └── aggregation_engine.py
│       │   │   │
│       │   │   ├── processors/
│       │   │   │   ├── alert_processor.py
│       │   │   │   ├── severity_processor.py
│       │   │   │   └── deduplication_processor.py
│       │   │   │
│       │   │   ├── managers/
│       │   │   │   ├── alert_manager.py
│       │   │   │   ├── notification_manager.py
│       │   │   │   └── channel_manager.py
│       │   │   │
│       │   │   ├── templates/
│       │   │   │   ├── email_templates.py
│       │   │   │   ├── slack_templates.py
│       │   │   │   └── sms_templates.py
│       │   │   │
│       │   │   └── __init__.py
│       │   │
│       │   ├── channels/
│       │   │   ├── email/
│       │   │   │   ├── email_sender.py
│       │   │   │   ├── email_formatter.py
│       │   │   │   └── email_config.py
│       │   │   │
│       │   │   ├── sms/
│       │   │   │   ├── sms_sender.py
│       │   │   │   ├── sms_formatter.py
│       │   │   │   └── sms_config.py
│       │   │   │
│       │   │   ├── slack/
│       │   │   │   ├── slack_sender.py
│       │   │   │   ├── slack_formatter.py
│       │   │   │   └── slack_config.py
│       │   │   │
│       │   │   ├── pagerduty/
│       │   │   │   ├── pagerduty_sender.py
│       │   │   │   ├── pagerduty_formatter.py
│       │   │   │   └── pagerduty_config.py
│       │   │   │
│       │   │   └── __init__.py
│       │   │
│       │   ├── infrastructure/
│       │   │   ├── database/
│       │   │   │   ├── dynamodb/
│       │   │   │   │   ├── alert_repository.py
│       │   │   │   │   └── notification_repository.py
│       │   │   │   │
│       │   │   │   └── postgres/
│       │   │   │       └── channel_config_repository.py
│       │   │   │
│       │   │   ├── messaging/
│       │   │   │   ├── sqs_consumer.py
│       │   │   │   ├── sns_publisher.py
│       │   │   │   └── event_bus.py
│       │   │   │
│       │   │   ├── cache/
│       │   │   │   ├── alert_cache.py
│       │   │   │   └── notification_cache.py
│       │   │   │
│       │   │   ├── storage/
│       │   │   │   └── s3_storage.py
│       │   │   │
│       │   │   ├── monitoring/
│       │   │   │   ├── telemetry.py
│       │   │   │   ├── metrics.py
│       │   │   │   └── health.py
│       │   │   │
│       │   │   ├── config/
│       │   │   │   ├── settings.py
│       │   │   │   ├── logging_config.py
│       │   │   │   └── aws_config.py
│       │   │   │
│       │   │   └── __init__.py
│       │   │
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   ├── alert.py
│       │   │   │   ├── notification.py
│       │   │   │   ├── channel.py
│       │   │   │   └── escalation_policy.py
│       │   │   │
│       │   │   ├── value_objects/
│       │   │   │   ├── severity.py
│       │   │   │   ├── status.py
│       │   │   │   └── channel_type.py
│       │   │   │
│       │   │   ├── events/
│       │   │   │   ├── alert_created_event.py
│       │   │   │   ├── alert_acknowledged_event.py
│       │   │   │   ├── alert_resolved_event.py
│       │   │   │   └── notification_sent_event.py
│       │   │   │
│       │   │   ├── enums/
│       │   │   │   ├── alert_severity.py
│       │   │   │   ├── alert_status.py
│       │   │   │   └── channel_type.py
│       │   │   │
│       │   │   └── __init__.py
│       │   │
│       │   ├── utils/
│       │   │   ├── logger.py
│       │   │   ├── validators.py
│       │   │   ├── decorators.py
│       │   │   ├── helpers.py
│       │   │   ├── rate_limiter.py
│       │   │   └── circuit_breaker.py
│       │   │
│       │   └── main.py
│       │
│       ├── tests/
│       │   ├── unit/
│       │   │   ├── core/
│       │   │   │   ├── test_alert_service.py
│       │   │   │   ├── test_notification_service.py
│       │   │   │   └── test_escalation_service.py
│       │   │   │
│       │   │   ├── channels/
│       │   │   │   ├── test_email_channel.py
│       │   │   │   ├── test_slack_channel.py
│       │   │   │   └── test_pagerduty_channel.py
│       │   │   │
│       │   │   ├── domain/
│       │   │   │   ├── test_alert.py
│       │   │   │   └── test_notification.py
│       │   │   │
│       │   │   ├── infrastructure/
│       │   │   │   ├── test_alert_repository.py
│       │   │   │   └── test_notification_repository.py
│       │   │   │
│       │   │   ├── api/
│       │   │   │   ├── test_alerts.py
│       │   │   │   └── test_notifications.py
│       │   │   │
│       │   │   ├── fixtures/
│       │   │   │   ├── alert_fixtures.py
│       │   │   │   └── notification_fixtures.py
│       │   │   │
│       │   │   └── conftest.py
│       │   │
│       │   ├── integration/
│       │   │   ├── test_dynamodb.py
│       │   │   ├── test_sqs.py
│       │   │   ├── test_sns.py
│       │   │   ├── test_notification_pipeline.py
│       │   │   └── conftest.py
│       │   │
│       │   └── e2e/
│       │       ├── test_end_to_end.py
│       │       └── test_scenarios.py
│       │
│       ├── scripts/
│       │   ├── seed_alerts.py
│       │   ├── test_notifications.py
│       │   └── cleanup_alerts.py
│       │
│       ├── templates/
│       │   ├── email/
│       │   │   ├── alert_email.html
│       │   │   ├── alert_email.txt
│       │   │   └── digest_email.html
│       │   │
│       │   └── slack/
│       │       ├── alert_slack.json
│       │       └── digest_slack.json
│       │
│       ├── requirements.txt
│       ├── requirements-dev.txt
│       ├── setup.py
│       ├── Dockerfile
│       ├── Dockerfile.dev
│       ├── .dockerignore
│       ├── .env.example
│       ├── .flake8
│       ├── .pylintrc
│       ├── pytest.ini
│       └── README.md
│
├── infrastructure/
│   ├── terraform/
│   │   ├── environments/
│   │   │   ├── dev/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   └── terraform.tfvars
│   │   │   ├── staging/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   └── terraform.tfvars
│   │   │   └── prod/
│   │   │       ├── main.tf
│   │   │       ├── variables.tf
│   │   │       ├── outputs.tf
│   │   │       └── terraform.tfvars
│   │   │
│   │   ├── modules/
│   │   │   ├── networking/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   └── README.md
│   │   │   │
│   │   │   ├── eks/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   ├── node_groups.tf
│   │   │   │   ├── addons.tf
│   │   │   │   └── README.md
│   │   │   │
│   │   │   ├── ecs/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   └── README.md
│   │   │   │
│   │   │   ├── databases/
│   │   │   │   ├── aurora/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   └── dynamodb/
│   │   │   │       ├── main.tf
│   │   │   │       ├── variables.tf
│   │   │   │       ├── outputs.tf
│   │   │   │       └── README.md
│   │   │   │
│   │   │   ├── messaging/
│   │   │   │   ├── sqs/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   ├── sns/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   └── eventbridge/
│   │   │   │       ├── main.tf
│   │   │   │       ├── variables.tf
│   │   │   │       ├── outputs.tf
│   │   │   │       └── README.md
│   │   │   │
│   │   │   ├── security/
│   │   │   │   ├── iam/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   ├── secrets_manager/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   └── cognito/
│   │   │   │       ├── main.tf
│   │   │   │       ├── variables.tf
│   │   │   │       ├── outputs.tf
│   │   │   │       └── README.md
│   │   │   │
│   │   │   ├── monitoring/
│   │   │   │   ├── cloudwatch/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   ├── xray/
│   │   │   │   │   ├── main.tf
│   │   │   │   │   ├── variables.tf
│   │   │   │   │   ├── outputs.tf
│   │   │   │   │   └── README.md
│   │   │   │   │
│   │   │   │   └── opentelemetry/
│   │   │   │       ├── main.tf
│   │   │   │       ├── variables.tf
│   │   │   │       ├── outputs.tf
│   │   │   │       └── README.md
│   │   │   │
│   │   │   ├── ecr/
│   │   │   │   ├── main.tf
│   │   │   │   ├── variables.tf
│   │   │   │   ├── outputs.tf
│   │   │   │   └── README.md
│   │   │   │
│   │   │   └── cicd/
│   │   │       ├── codebuild/
│   │   │       │   ├── main.tf
│   │   │       │   ├── variables.tf
│   │   │       │   ├── outputs.tf
│   │   │       │   └── README.md
│   │   │       │
│   │   │       └── codepipeline/
│   │   │           ├── main.tf
│   │   │           ├── variables.tf
│   │   │           ├── outputs.tf
│   │   │           └── README.md
│   │   │
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── backend.tf
│   │   ├── data.tf
│   │   └── README.md
│   │
│   ├── kubernetes/
│   │   ├── base/
│   │   │   ├── namespaces/
│   │   │   │   ├── renewable-energy.yaml
│   │   │   │   ├── observability.yaml
│   │   │   │   └── security.yaml
│   │   │   │
│   │   │   ├── configmaps/
│   │   │   │   ├── asset-service-config.yaml
│   │   │   │   ├── telemetry-service-config.yaml
│   │   │   │   ├── anomaly-detection-config.yaml
│   │   │   │   ├── maintenance-service-config.yaml
│   │   │   │   └── alert-service-config.yaml
│   │   │   │
│   │   │   ├── secrets/
│   │   │   │   ├── asset-service-secrets.yaml
│   │   │   │   ├── telemetry-service-secrets.yaml
│   │   │   │   ├── anomaly-detection-secrets.yaml
│   │   │   │   ├── maintenance-service-secrets.yaml
│   │   │   │   ├── alert-service-secrets.yaml
│   │   │   │   └── aws-credentials.yaml
│   │   │   │
│   │   │   ├── serviceaccounts/
│   │   │   │   ├── asset-service-sa.yaml
│   │   │   │   ├── telemetry-service-sa.yaml
│   │   │   │   ├── anomaly-detection-sa.yaml
│   │   │   │   ├── maintenance-service-sa.yaml
│   │   │   │   └── alert-service-sa.yaml
│   │   │   │
│   │   │   ├── deployments/
│   │   │   │   ├── asset-service-deployment.yaml
│   │   │   │   ├── telemetry-service-deployment.yaml
│   │   │   │   ├── anomaly-detection-deployment.yaml
│   │   │   │   ├── maintenance-service-deployment.yaml
│   │   │   │   └── alert-service-deployment.yaml
│   │   │   │
│   │   │   ├── services/
│   │   │   │   ├── asset-service-service.yaml
│   │   │   │   ├── telemetry-service-service.yaml
│   │   │   │   ├── anomaly-detection-service.yaml
│   │   │   │   ├── maintenance-service-service.yaml
│   │   │   │   ├── alert-service-service.yaml
│   │   │   │   └── redis-service.yaml
│   │   │   │
│   │   │   ├── ingresses/
│   │   │   │   ├── renewable-energy-ingress.yaml
│   │   │   │   └── renewable-energy-ingress-dev.yaml
│   │   │   │
│   │   │   ├── hpa/
│   │   │   │   ├── asset-service-hpa.yaml
│   │   │   │   ├── telemetry-service-hpa.yaml
│   │   │   │   ├── anomaly-detection-hpa.yaml
│   │   │   │   ├── maintenance-service-hpa.yaml
│   │   │   │   └── alert-service-hpa.yaml
│   │   │   │
│   │   │   ├── pdb/
│   │   │   │   ├── asset-service-pdb.yaml
│   │   │   │   ├── telemetry-service-pdb.yaml
│   │   │   │   └── maintenance-service-pdb.yaml
│   │   │   │
│   │   │   ├── networkpolicies/
│   │   │   │   ├── allow-egress.yaml
│   │   │   │   ├── allow-ingress.yaml
│   │   │   │   └── deny-all.yaml
│   │   │   │
│   │   │   ├── podsecuritypolicies/
│   │   │   │   └── restricted-psp.yaml
│   │   │   │
│   │   │   ├── roles/
│   │   │   │   ├── pod-reader-role.yaml
│   │   │   │   └── secret-reader-role.yaml
│   │   │   │
│   │   │   └── rolebindings/
│   │   │       ├── pod-reader-rolebinding.yaml
│   │   │       └── secret-reader-rolebinding.yaml
│   │   │
│   │   └── overlays/
│   │       ├── dev/
│   │       │   ├── kustomization.yaml
│   │       │   ├── replicas.yaml
│   │       │   ├── patch-deployment.yaml
│   │       │   ├── patch-service.yaml
│   │       │   ├── configmap-patch.yaml
│   │       │   ├── ingress-patch.yaml
│   │       │   └── dev-env.yaml
│   │       │
│   │       ├── staging/
│   │       │   ├── kustomization.yaml
│   │       │   ├── replicas.yaml
│   │       │   ├── patch-deployment.yaml
│   │       │   ├── patch-service.yaml
│   │       │   ├── configmap-patch.yaml
│   │       │   ├── ingress-patch.yaml
│   │       │   └── staging-env.yaml
│   │       │
│   │       └── prod/
│   │           ├── kustomization.yaml
│   │           ├── replicas.yaml
│   │           ├── patch-deployment.yaml
│   │           ├── patch-service.yaml
│   │           ├── configmap-patch.yaml
│   │           ├── ingress-patch.yaml
│   │           ├── prod-env.yaml
│   │           ├── hpa-patch.yaml
│   │           └── pdb-patch.yaml
│   │
│   ├── helm-charts/
│   │   ├── asset-service/
│   │   │   ├── templates/
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   ├── configmap.yaml
│   │   │   │   ├── secrets.yaml
│   │   │   │   ├── serviceaccount.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   ├── pdb.yaml
│   │   │   │   ├── networkpolicy.yaml
│   │   │   │   ├── servicemonitor.yaml
│   │   │   │   └── tests/
│   │   │   │       └── test-connection.yaml
│   │   │   │
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   ├── values-staging.yaml
│   │   │   ├── values-prod.yaml
│   │   │   ├── Chart.yaml
│   │   │   ├── .helmignore
│   │   │   └── README.md
│   │   │
│   │   ├── telemetry-service/
│   │   │   ├── templates/
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   ├── configmap.yaml
│   │   │   │   ├── secrets.yaml
│   │   │   │   ├── serviceaccount.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   ├── pdb.yaml
│   │   │   │   ├── networkpolicy.yaml
│   │   │   │   ├── servicemonitor.yaml
│   │   │   │   └── tests/
│   │   │   │       └── test-connection.yaml
│   │   │   │
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   ├── values-staging.yaml
│   │   │   ├── values-prod.yaml
│   │   │   ├── Chart.yaml
│   │   │   ├── .helmignore
│   │   │   └── README.md
│   │   │
│   │   ├── anomaly-detection-service/
│   │   │   ├── templates/
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   ├── configmap.yaml
│   │   │   │   ├── secrets.yaml
│   │   │   │   ├── serviceaccount.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   ├── pdb.yaml
│   │   │   │   ├── networkpolicy.yaml
│   │   │   │   ├── servicemonitor.yaml
│   │   │   │   └── tests/
│   │   │   │       └── test-connection.yaml
│   │   │   │
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   ├── values-staging.yaml
│   │   │   ├── values-prod.yaml
│   │   │   ├── Chart.yaml
│   │   │   ├── .helmignore
│   │   │   └── README.md
│   │   │
│   │   ├── maintenance-service/
│   │   │   ├── templates/
│   │   │   │   ├── _helpers.tpl
│   │   │   │   ├── deployment.yaml
│   │   │   │   ├── service.yaml
│   │   │   │   ├── ingress.yaml
│   │   │   │   ├── configmap.yaml
│   │   │   │   ├── secrets.yaml
│   │   │   │   ├── serviceaccount.yaml
│   │   │   │   ├── hpa.yaml
│   │   │   │   ├── pdb.yaml
│   │   │   │   ├── networkpolicy.yaml
│   │   │   │   ├── servicemonitor.yaml
│   │   │   │   └── tests/
│   │   │   │       └── test-connection.yaml
│   │   │   │
│   │   │   ├── values.yaml
│   │   │   ├── values-dev.yaml
│   │   │   ├── values-staging.yaml
│   │   │   ├── values-prod.yaml
│   │   │   ├── Chart.yaml
│   │   │   ├── .helmignore
│   │   │   └── README.md
│   │   │
│   │   └── alert-service/
│   │       ├── templates/
│   │       │   ├── _helpers.tpl
│   │       │   ├── deployment.yaml
│   │       │   ├── service.yaml
│   │       │   ├── ingress.yaml
│   │       │   ├── configmap.yaml
│   │       │   ├── secrets.yaml
│   │       │   ├── serviceaccount.yaml
│   │       │   ├── hpa.yaml
│   │       │   ├── pdb.yaml
│   │       │   ├── networkpolicy.yaml
│   │       │   ├── servicemonitor.yaml
│   │       │   └── tests/
│   │       │       └── test-connection.yaml
│   │       │
│   │       ├── values.yaml
│   │       ├── values-dev.yaml
│   │       ├── values-staging.yaml
│   │       ├── values-prod.yaml
│   │       ├── Chart.yaml
│   │       ├── .helmignore
│   │       └── README.md
│   │
│   ├── docker-compose/
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.dev.yml
│   │   ├── docker-compose.prod.yml
│   │   └── docker-compose.override.yml
│   │
│   ├── monitoring/
│   │   ├── prometheus/
│   │   │   ├── prometheus.yml
│   │   │   ├── alerting_rules.yml
│   │   │   ├── recording_rules.yml
│   │   │   └── targets.yml
│   │   │
│   │   ├── grafana/
│   │   │   ├── dashboards/
│   │   │   │   ├── asset-service-dashboard.json
│   │   │   │   ├── telemetry-service-dashboard.json
│   │   │   │   ├── anomaly-detection-dashboard.json
│   │   │   │   ├── maintenance-service-dashboard.json
│   │   │   │   ├── alert-service-dashboard.json
│   │   │   │   ├── infrastructure-dashboard.json
│   │   │   │   └── business-dashboard.json
│   │   │   │
│   │   │   └── datasources/
│   │   │       ├── prometheus-datasource.yaml
│   │   │       ├── cloudwatch-datasource.yaml
│   │   │       └── jaeger-datasource.yaml
│   │   │
│   │   └── opentelemetry/
│   │       ├── collector-config.yml
│   │       ├── agent-config.yml
│   │       └── gateway-config.yml
│   │
│   └── logging/
│       ├── fluentbit/
│       │   ├── fluentbit.conf
│       │   └── parsers.conf
│       │
│       └── elasticsearch/
│           ├── elasticsearch.yml
│           └── kibana.yml
│
├── ci-cd/
│   ├── codebuild/
│   │   ├── buildspec.yml
│   │   ├── buildspec-test.yml
│   │   ├── buildspec-sonar.yml
│   │   ├── buildspec-security.yml
│   │   ├── buildspec-package.yml
│   │   └── buildspec-deploy.yml
│   │
│   ├── codepipeline/
│   │   ├── pipeline.yml
│   │   ├── pipeline-dev.yml
│   │   ├── pipeline-staging.yml
│   │   ├── pipeline-prod.yml
│   │   └── pipeline-parameters.json
│   │
│   ├── github-actions/
│   │   ├── ci.yml
│   │   ├── cd.yml
│   │   ├── security-scan.yml
│   │   ├── performance-test.yml
│   │   └── release.yml
│   │
│   └── scripts/
│       ├── build-all.sh
│       ├── push-images.sh
│       ├── deploy-dev.sh
│       ├── deploy-staging.sh
│       ├── deploy-prod.sh
│       ├── rollback.sh
│       ├── smoke-test.sh
│       ├── e2e-test.sh
│       └── cleanup.sh
│
├── docs/
│   ├── architecture/
│   │   ├── architecture-diagram.mermaid
│   │   ├── sequence-diagrams/
│   │   │   ├── asset-registration-sequence.mermaid
│   │   │   ├── telemetry-processing-sequence.mermaid
│   │   │   ├── anomaly-detection-sequence.mermaid
│   │   │   └── alert-generation-sequence.mermaid
│   │   │
│   │   ├── data-flow/
│   │   │   ├── data-flow-diagram.mermaid
│   │   │   └── event-flow-diagram.mermaid
│   │   │
│   │   └── deployment/
│   │       ├── eks-architecture.mermaid
│   │       └── networking-diagram.mermaid
│   │
│   ├── api/
│   │   ├── openapi/
│   │   │   ├── asset-service-openapi.yaml
│   │   │   ├── telemetry-service-openapi.yaml
│   │   │   ├── anomaly-detection-openapi.yaml
│   │   │   ├── maintenance-service-openapi.yaml
│   │   │   └── alert-service-openapi.yaml
│   │   │
│   │   ├── postman/
│   │   │   ├── Renewable-Energy-Platform.postman_collection.json
│   │   │   └── Renewable-Energy-Platform.postman_environment.json
│   │   │
│   │   └── examples/
│   │       ├── asset-examples.json
│   │       ├── telemetry-examples.json
│   │       └── anomaly-examples.json
│   │
│   ├── guides/
│   │   ├── getting-started.md
│   │   ├── local-development.md
│   │   ├── deployment-guide.md
│   │   ├── monitoring-guide.md
│   │   ├── troubleshooting.md
│   │   └── performance-tuning.md
│   │
│   ├── architecture-decision-records/
│   │   ├── 001-use-event-driven-architecture.md
│   │   ├── 002-choose-aspnet-core-for-services.md
│   │   ├── 003-use-dynamodb-for-telemetry.md
│   │   ├── 004-implement-cqrs-pattern.md
│   │   ├── 005-use-eks-for-orchestration.md
│   │   └── 006-open-telemetry-for-observability.md
│   │
│   └── ADR.md
│
├── scripts/
│   ├── dev/
│   │   ├── setup-local.sh
│   │   ├── init-databases.sh
│   │   ├── seed-data.sh
│   │   ├── start-services.sh
│   │   ├── stop-services.sh
│   │   ├── clean-local.sh
│   │   └── generate-test-data.sh
│   │
│   ├── deployment/
│   │   ├── deploy-infrastructure.sh
│   │   ├── deploy-services.sh
│   │   ├── setup-kubernetes.sh
│   │   ├── setup-helm.sh
│   │   ├── setup-cicd.sh
│   │   └── validate-deployment.sh
│   │
│   ├── monitoring/
│   │   ├── setup-prometheus.sh
│   │   ├── setup-grafana.sh
│   │   ├── setup-jaeger.sh
│   │   ├── setup-xray.sh
│   │   └── setup-otel-collector.sh
│   │
│   └── security/
│       ├── rotate-secrets.sh
│       ├── generate-jwt-keys.sh
│       ├── setup-iam-roles.sh
│       └── security-audit.sh
│
├── .env.example
├── .gitignore
├── .dockerignore
├── .editorconfig
├── .pre-commit-config.yaml
├── LICENSE
├── README.md
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SECURITY.md
├── CODE_OF_CONDUCT.md
└── Makefile
```


```cmd
cd infrastructure/docker-compose
docker compose down -v
docker compose up --build
```


