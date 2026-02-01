# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy Solution and Project files first for caching
COPY *.sln .
COPY Pcm.Api/*.csproj Pcm.Api/
COPY Pcm.Application/*.csproj Pcm.Application/
COPY Pcm.Domain/*.csproj Pcm.Domain/
COPY Pcm.Infrastructure/*.csproj Pcm.Infrastructure/

# Restore dependencies
RUN dotnet restore

# Copy all code
COPY . .

# Build and Publish
WORKDIR /src/Pcm.Api
RUN dotnet publish -c Release -o /app/publish

# Runtime Stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Expose Port (Render uses PORT env var, but this documents intent)
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

# Entrypoint
ENTRYPOINT ["dotnet", "Pcm.Api.dll"]
