using Amazon;
using Amazon.SQS;
using Application.Interfaces;
using Application.Mappings;
using FluentValidation;
using Infrastructure.Context;
using Infrastructure.Repositories;
using Infrastructure.Services;
using Microsoft.EntityFrameworkCore;

namespace API;

public class Startup
{
    private readonly IConfiguration _configuration;

    public Startup(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public void ConfigureServices(IServiceCollection services)
    {
        services.AddControllers(options =>
        {
            options.Filters.Add<API.Filters.ValidationFilter>();
        });

        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(c =>
        {
            c.SwaggerDoc("v1", new Microsoft.OpenApi.Models.OpenApiInfo
            {
                Title = "Asset Service API",
                Version = "v1",
                Description = "Smart Renewable Energy Platform – Asset Management Service"
            });
        });

        // Database
        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseNpgsql(_configuration.GetConnectionString("DefaultConnection")));

        // Redis Cache
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = _configuration["Redis:ConnectionString"] ?? "localhost:6379";
        });

        // MediatR
        services.AddMediatR(cfg =>
            cfg.RegisterServicesFromAssembly(typeof(Startup).Assembly)
               .RegisterServicesFromAssembly(typeof(Application.Interfaces.IAssetRepository).Assembly));

        // AutoMapper
        services.AddAutoMapper(typeof(AssetMappingProfile).Assembly);

        // FluentValidation — register validators from Application assembly (used by MediatR pipeline)
        services.AddValidatorsFromAssembly(typeof(IAssetRepository).Assembly);

        // AWS
        var awsOptions = new Amazon.Extensions.NETCore.Setup.AWSOptions
        {
            Region = RegionEndpoint.GetBySystemName(_configuration["AWS:Region"] ?? "us-east-1"),
            DefaultClientConfig = { ServiceURL = _configuration["AWS:ServiceURL"] }
        };
        services.AddDefaultAWSOptions(awsOptions);
        services.AddAWSService<IAmazonSQS>();

        // Application services
        services.AddScoped<IAssetRepository, AssetRepository>();
        services.AddScoped<IEventPublisher, SqsEventPublisher>();
        services.AddScoped<ICacheService, RedisCacheService>();

        services.AddHttpContextAccessor();
        services.AddHealthChecks()
            .AddNpgSql(_configuration.GetConnectionString("DefaultConnection")!, name: "postgres")
            .AddRedis(_configuration["Redis:ConnectionString"] ?? "localhost:6379", name: "redis");

        services.AddCors(options =>
        {
            options.AddDefaultPolicy(policy =>
                policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
        });
    }

    public void Configure(WebApplication app, IWebHostEnvironment env)
    {
        if (env.IsDevelopment())
        {
            app.UseDeveloperExceptionPage();
        }

        app.UseSwagger();
        app.UseSwaggerUI(c =>
        {
            c.SwaggerEndpoint("/swagger/v1/swagger.json", "Asset Service API v1");
            c.RoutePrefix = string.Empty;
        });

        app.UseCors();

        app.UseMiddleware<API.Middleware.ExceptionHandlingMiddleware>();
        app.UseMiddleware<API.Middleware.CorrelationIdMiddleware>();
        app.UseMiddleware<API.Middleware.RequestLoggingMiddleware>();

        app.UseAuthorization();
        app.MapControllers();
        app.MapHealthChecks("/health");

        using var scope = app.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        InitialiseDatabase(db);
    }

    // Uses raw ADO.NET to avoid EF Core's RawSqlCommandBuilder which calls String.Format
    // and chokes on { } characters inside JSON metadata values.
    private static void InitialiseDatabase(ApplicationDbContext db)
    {
        db.Database.OpenConnection();
        try
        {
            var conn = db.Database.GetDbConnection();
            Sql(conn, @"
                CREATE TABLE IF NOT EXISTS ""Assets"" (
                    ""Id""                  uuid                     NOT NULL,
                    ""Name""                character varying(200)   NOT NULL,
                    ""Type""                text                     NOT NULL,
                    ""Status""              text                     NOT NULL,
                    ""Latitude""            double precision         NOT NULL,
                    ""Longitude""           double precision         NOT NULL,
                    ""Elevation""           double precision,
                    ""CapacityValue""       double precision         NOT NULL,
                    ""CapacityUnit""        text                     NOT NULL DEFAULT 'MW',
                    ""InstallationDate""    timestamp with time zone NOT NULL,
                    ""LastMaintenanceDate"" timestamp with time zone,
                    ""Metadata""            text                     NOT NULL DEFAULT '{}',
                    CONSTRAINT ""PK_Assets"" PRIMARY KEY (""Id"")
                )");

            Sql(conn, @"
                CREATE TABLE IF NOT EXISTS ""MaintenanceSchedules"" (
                    ""Id""            uuid                     NOT NULL,
                    ""AssetId""       uuid                     NOT NULL,
                    ""ScheduledDate"" timestamp with time zone NOT NULL,
                    ""CompletedDate"" timestamp with time zone,
                    ""Type""          character varying(100)   NOT NULL,
                    ""Notes""         character varying(1000)  NOT NULL DEFAULT '',
                    CONSTRAINT ""PK_MaintenanceSchedules"" PRIMARY KEY (""Id""),
                    CONSTRAINT ""FK_MaintenanceSchedules_Assets_AssetId""
                        FOREIGN KEY (""AssetId"") REFERENCES ""Assets"" (""Id"") ON DELETE CASCADE
                )");

            Sql(conn, @"
                INSERT INTO ""Assets""
                    (""Id"",""Name"",""Type"",""Status"",""Latitude"",""Longitude"",""Elevation"",
                     ""CapacityValue"",""CapacityUnit"",""InstallationDate"",""LastMaintenanceDate"",""Metadata"")
                VALUES
                    ('11111111-0000-0000-0000-000000000001','North Wind Farm Alpha','WindTurbine','Active',
                     53.4808,-2.2426,NULL,4.5,'MW','2021-03-15 00:00:00+00','2024-01-10 00:00:00+00',
                     '{""manufacturer"":""Vestas"",""model"":""V150-4.5"",""hub_height"":""120m""}'),
                    ('11111111-0000-0000-0000-000000000002','Solar Park Beta','SolarFarm','Active',
                     35.6892,-116.5723,NULL,50.0,'MW','2022-06-01 00:00:00+00','2024-02-05 00:00:00+00',
                     '{""manufacturer"":""SunPower"",""panel_count"":""5000"",""inverter"":""SMA""}'),
                    ('11111111-0000-0000-0000-000000000003','Wind Turbine Gamma','WindTurbine','Maintenance',
                     51.5074,-0.1278,NULL,4.5,'MW','2020-09-20 00:00:00+00','2024-06-01 00:00:00+00',
                     '{""manufacturer"":""Siemens Gamesa"",""model"":""SG 5.0-145"",""hub_height"":""115m""}'),
                    ('11111111-0000-0000-0000-000000000004','Hydro Station Delta','HydroElectric','Active',
                     47.6062,-120.5015,NULL,25.0,'MW','2019-04-12 00:00:00+00','2023-11-20 00:00:00+00',
                     '{""river"":""Green River"",""turbines"":""3"",""dam_height"":""45m""}'),
                    ('11111111-0000-0000-0000-000000000005','Battery Storage Epsilon','BatteryStorage','Active',
                     40.7128,-74.006,NULL,100.0,'MW','2023-01-08 00:00:00+00',NULL,
                     '{""manufacturer"":""Tesla"",""model"":""Megapack"",""chemistry"":""LFP""}')
                ON CONFLICT (""Id"") DO NOTHING");
        }
        finally
        {
            db.Database.CloseConnection();
        }
    }

    private static void Sql(System.Data.Common.DbConnection conn, string sql)
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = sql;
        cmd.ExecuteNonQuery();
    }
}
