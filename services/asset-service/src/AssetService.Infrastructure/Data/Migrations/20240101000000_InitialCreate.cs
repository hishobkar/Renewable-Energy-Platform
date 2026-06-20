using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Infrastructure.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Assets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Type = table.Column<string>(type: "text", nullable: false),
                    Status = table.Column<string>(type: "text", nullable: false),
                    Latitude = table.Column<double>(type: "double precision", nullable: false),
                    Longitude = table.Column<double>(type: "double precision", nullable: false),
                    Elevation = table.Column<double>(type: "double precision", nullable: true),
                    CapacityValue = table.Column<double>(type: "double precision", nullable: false),
                    CapacityUnit = table.Column<string>(type: "text", nullable: false, defaultValue: "MW"),
                    InstallationDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    LastMaintenanceDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Metadata = table.Column<string>(type: "text", nullable: false, defaultValue: "{}")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Assets", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "MaintenanceSchedules",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    AssetId = table.Column<Guid>(type: "uuid", nullable: false),
                    ScheduledDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CompletedDate = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Notes = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MaintenanceSchedules", x => x.Id);
                });

            // Seed initial assets
            migrationBuilder.InsertData(
                table: "Assets",
                columns: new[] { "Id", "Name", "Type", "Status", "Latitude", "Longitude", "Elevation", "CapacityValue", "CapacityUnit", "InstallationDate", "LastMaintenanceDate", "Metadata" },
                values: new object[,]
                {
                    { Guid.Parse("11111111-0000-0000-0000-000000000001"), "North Wind Farm Alpha", "WindTurbine", "Active", 53.4808, -2.2426, (double?)null, 4.5, "MW", new DateTime(2021, 3, 15, 0, 0, 0, DateTimeKind.Utc), new DateTime(2024, 1, 10, 0, 0, 0, DateTimeKind.Utc), "{\"manufacturer\":\"Vestas\",\"model\":\"V150-4.5\",\"hub_height\":\"120m\"}" },
                    { Guid.Parse("11111111-0000-0000-0000-000000000002"), "Solar Park Beta", "SolarFarm", "Active", 35.6892, -116.5723, (double?)null, 50.0, "MW", new DateTime(2022, 6, 1, 0, 0, 0, DateTimeKind.Utc), new DateTime(2024, 2, 5, 0, 0, 0, DateTimeKind.Utc), "{\"manufacturer\":\"SunPower\",\"panel_count\":\"5000\",\"inverter\":\"SMA\"}" },
                    { Guid.Parse("11111111-0000-0000-0000-000000000003"), "Wind Turbine Gamma", "WindTurbine", "Maintenance", 51.5074, -0.1278, (double?)null, 4.5, "MW", new DateTime(2020, 9, 20, 0, 0, 0, DateTimeKind.Utc), new DateTime(2024, 6, 1, 0, 0, 0, DateTimeKind.Utc), "{\"manufacturer\":\"Siemens Gamesa\",\"model\":\"SG 5.0-145\",\"hub_height\":\"115m\"}" },
                    { Guid.Parse("11111111-0000-0000-0000-000000000004"), "Hydro Station Delta", "HydroElectric", "Active", 47.6062, -120.5015, (double?)null, 25.0, "MW", new DateTime(2019, 4, 12, 0, 0, 0, DateTimeKind.Utc), new DateTime(2023, 11, 20, 0, 0, 0, DateTimeKind.Utc), "{\"river\":\"Green River\",\"turbines\":\"3\",\"dam_height\":\"45m\"}" },
                    { Guid.Parse("11111111-0000-0000-0000-000000000005"), "Battery Storage Epsilon", "BatteryStorage", "Active", 40.7128, -74.006, (double?)null, 100.0, "MW", new DateTime(2023, 1, 8, 0, 0, 0, DateTimeKind.Utc), (DateTime?)null, "{\"manufacturer\":\"Tesla\",\"model\":\"Megapack\",\"chemistry\":\"LFP\"}" }
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "MaintenanceSchedules");
            migrationBuilder.DropTable(name: "Assets");
        }
    }
}
