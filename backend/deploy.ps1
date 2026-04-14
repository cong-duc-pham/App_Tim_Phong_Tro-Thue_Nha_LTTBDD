param(
    [switch]$IIS,
    [switch]$Run,
    [string]$Tag = "phongtro-api:latest",
    [int]$Port = 5000
)

$ErrorActionPreference = "Stop"
$DockerContextDir = Join-Path $PSScriptRoot "Backend_API"
$ApiProjectDir = Join-Path $DockerContextDir "Backend_API"
$PublishDir = Join-Path $ApiProjectDir "publish"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  PhongTro API - Deploy Script (Docker First)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Building project..." -ForegroundColor Yellow
dotnet build "$ApiProjectDir\Backend_API.csproj" -c Release --nologo -v q
if ($LASTEXITCODE -ne 0) {
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    exit 1
}
Write-Host "  Build OK" -ForegroundColor Green

if ($IIS) {
    Write-Host "[2/4] Publishing for IIS fallback to $PublishDir ..." -ForegroundColor Yellow
    if (Test-Path $PublishDir) { Remove-Item -Recurse -Force $PublishDir }
    dotnet publish "$ApiProjectDir\Backend_API.csproj" -c Release -o $PublishDir --nologo -v q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "PUBLISH FAILED!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Publish OK -> $PublishDir" -ForegroundColor Green
    Write-Host "[3/4] Docker build skipped because -IIS flag is enabled" -ForegroundColor Gray
    Write-Host "[4/4] Docker run skipped because -IIS flag is enabled" -ForegroundColor Gray
}
else {
    Write-Host "[2/4] Building Docker image: $Tag ..." -ForegroundColor Yellow
    docker build -t $Tag "$DockerContextDir"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "DOCKER BUILD FAILED!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Docker image OK -> $Tag" -ForegroundColor Green

    if ($Run) {
        Write-Host "[3/4] Running Docker container on port $Port ..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Use environment variables to override:" -ForegroundColor Gray
        Write-Host "    -e ConnectionStrings__DefaultConnection=..." -ForegroundColor Gray
        Write-Host "    -e JwtSettings__SecretKey=..." -ForegroundColor Gray
        Write-Host "    -e FIREBASE_CREDENTIALS_JSON=..." -ForegroundColor Gray
        Write-Host "    -e Swagger__Enabled=true|false" -ForegroundColor Gray
        Write-Host ""
        docker run -d -p "${Port}:8080" --name phongtro-api $Tag
        Write-Host "  Container running -> http://localhost:${Port}" -ForegroundColor Green
        Write-Host "  Swagger UI -> http://localhost:${Port}/swagger" -ForegroundColor Green
        Write-Host "[4/4] Runtime started" -ForegroundColor Green
    }
    else {
        Write-Host "[3/4] Docker run skipped (use -Run flag)" -ForegroundColor Gray
        Write-Host "[4/4] Ready to deploy image: $Tag" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  DEPLOYMENT CHECKLIST" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Required environment variables for Production:" -ForegroundColor Yellow
Write-Host "  - ConnectionStrings__DefaultConnection"
Write-Host "  - JwtSettings__SecretKey"
Write-Host "  - FIREBASE_CREDENTIALS_JSON"
Write-Host "  - Swagger__Enabled (optional)"
Write-Host "  - Cors__AllowedOrigins__0"
Write-Host ""
Write-Host "  Done!" -ForegroundColor Green
