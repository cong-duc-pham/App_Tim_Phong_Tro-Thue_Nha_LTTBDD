# ═══════════════════════════════════════════════════════════════════════
# PhongTro API — Multi-stage Docker Build
# ═══════════════════════════════════════════════════════════════════════
# Build:  docker build -t phongtro-api .
# Run:    docker run -p 5000:8080 \
#           -e "ConnectionStrings__DefaultConnection=Server=...;Database=PhongTroDB;..." \
#           -e "JwtSettings__SecretKey=YourProductionSecretKey" \
#           -e "FIREBASE_CREDENTIALS_JSON=$(cat firebase-adminsdk.json)" \
#           phongtro-api
# ═══════════════════════════════════════════════════════════════════════

# ── Stage 1: Build ───────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj trước để cache NuGet restore
COPY Backend_API/Backend_API.csproj Backend_API/
RUN dotnet restore Backend_API/Backend_API.csproj

# Copy toàn bộ source và build
COPY . .
WORKDIR /src/Backend_API
RUN dotnet publish -c Release -o /app/publish --no-restore

# ── Stage 2: Runtime ─────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Metadata
LABEL maintainer="PhongTro Team"
LABEL description="PhongTro API - Hệ thống tìm phòng trọ"

# Copy published output
COPY --from=build /app/publish .

# Copy Firebase credentials (nếu có, nếu không dùng env var)
# COPY Backend_API/firebase-adminsdk.json ./firebase-adminsdk.json

# Expose port (ASP.NET 8 mặc định listen trên 8080)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Biến môi trường mặc định
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

# Entry point
ENTRYPOINT ["dotnet", "Backend_API.dll"]
