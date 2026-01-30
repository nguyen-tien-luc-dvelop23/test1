# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj files and restore
COPY Pcm.Domain/Pcm.Domain.csproj Pcm.Domain/
COPY Pcm.Application/Pcm.Application.csproj Pcm.Application/
COPY Pcm.Infrastructure/Pcm.Infrastructure.csproj Pcm.Infrastructure/
COPY Pcm.Api/Pcm.Api.csproj Pcm.Api/
RUN dotnet restore Pcm.Api/Pcm.Api.csproj

# Copy everything and build
COPY . .
RUN dotnet publish Pcm.Api/Pcm.Api.csproj -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Expose port
EXPOSE 10000

# Set environment variables
ENV ASPNETCORE_URLS=http://+:10000
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "Pcm.Api.dll"]
