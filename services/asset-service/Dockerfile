FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/AssetService.Domain/AssetService.Domain.csproj src/AssetService.Domain/
COPY src/AssetService.Application/AssetService.Application.csproj src/AssetService.Application/
COPY src/AssetService.Infrastructure/AssetService.Infrastructure.csproj src/AssetService.Infrastructure/
COPY src/AssetService.API/AssetService.API.csproj src/AssetService.API/
RUN dotnet restore src/AssetService.API/AssetService.API.csproj

COPY src/ src/
RUN dotnet publish src/AssetService.API/AssetService.API.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "AssetService.API.dll"]
