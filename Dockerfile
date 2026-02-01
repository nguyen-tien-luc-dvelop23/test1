# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy Solution and Project files first for caching
# Adjusted paths for Root context
COPY backend/*.sln ./
COPY backend/Pcm.Api/*.csproj Pcm.Api/
COPY backend/Pcm.Application/*.csproj Pcm.Application/
COPY backend/Pcm.Domain/*.csproj Pcm.Domain/
COPY backend/Pcm.Infrastructure/*.csproj Pcm.Infrastructure/

# Restore dependencies
RUN dotnet restore

# Copy all code
COPY backend/. .

# Build and Publish
WORKDIR /src/Pcm.Api
RUN dotnet publish -c Release -o /app/publish

# Runtime Stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Expose Ports (Listen on both 8080 and 10000 to match Render's expectations)
EXPOSE 8080
EXPOSE 10000
ENV ASPNETCORE_URLS=http://+:8080;http://+:10000

# Entrypoint
ENTRYPOINT ["dotnet", "Pcm.Api.dll"]
