# Production Runbook - Backend API (Docker-first)

## 1) Build image

```powershell
Set-Location .\backend
.\deploy.ps1
```

Default path is Docker image build. IIS fallback:

```powershell
.\deploy.ps1 -IIS
```

## 2) Required environment variables

```text
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__DefaultConnection=Server=<PROD_SERVER>;Database=PhongTroDB;User Id=<USER>;Password=<PASSWORD>;TrustServerCertificate=True;
JwtSettings__SecretKey=<32+ chars secret>
JwtSettings__Issuer=PhongTroAPI
JwtSettings__Audience=PhongTroApp
JwtSettings__ExpireHours=24
Firebase__ProjectId=app-tim-phong-tro-thue-n-dacfe
Firebase__StorageBucket=app-tim-phong-tro-thue-n-dacfe.appspot.com
FIREBASE_CREDENTIALS_JSON=<full JSON content of firebase-adminsdk.json>
Swagger__Enabled=true
Cors__AllowedOrigins__0=https://your-production-domain.com
```

Notes:
- Production connection string is environment-only.
- `Swagger__Enabled` can be `false` for public production.
- Never commit service account JSON file.

## 3) Run with Docker

```powershell
docker run -d `
  --name phongtro-api `
  -p 5000:8080 `
  -e ASPNETCORE_ENVIRONMENT=Production `
  -e ConnectionStrings__DefaultConnection="Server=<PROD_SERVER>;Database=PhongTroDB;User Id=<USER>;Password=<PASSWORD>;TrustServerCertificate=True;" `
  -e JwtSettings__SecretKey="<32+ chars secret>" `
  -e JwtSettings__Issuer="PhongTroAPI" `
  -e JwtSettings__Audience="PhongTroApp" `
  -e JwtSettings__ExpireHours="24" `
  -e Firebase__ProjectId="app-tim-phong-tro-thue-n-dacfe" `
  -e Firebase__StorageBucket="app-tim-phong-tro-thue-n-dacfe.appspot.com" `
  -e FIREBASE_CREDENTIALS_JSON="<service-account-json>" `
  -e Swagger__Enabled="true" `
  -e Cors__AllowedOrigins__0="https://your-production-domain.com" `
  phongtro-api:latest
```

## 4) Production docker-compose (recommended)

Files included in repo:
- `backend/docker-compose.prod.yml`
- `backend/.env.prod.example`

Setup:

```powershell
Set-Location .\backend
Copy-Item .env.prod.example .env.prod
# chỉnh giá trị thực tế trong .env.prod (DB/JWT/Firebase/CORS)
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d
```

Check:

```powershell
docker compose -f docker-compose.prod.yml --env-file .env.prod ps
docker logs phongtro-api --tail 200
```

## 5) Smoke test backend API

```powershell
Set-Location .\backend\scripts
.\smoke-test.ps1 -BaseUrl "http://localhost:5000"
```

## 6) Postman regression (Auth/Listing/Chat/Payment)

Files:
- `backend/postman/PhongTro_Phase9.postman_collection.json`
- `backend/postman/PhongTro_Local.postman_environment.json`

Run with Newman:

```powershell
npm install -g newman
newman run .\backend\postman\PhongTro_Phase9.postman_collection.json -e .\backend\postman\PhongTro_Local.postman_environment.json
```

## 7) Flutter E2E sanity checklist

1. Login email/password works and receives JWT.
2. Refresh token flow returns new JWT.
3. Create listing and fetch listing list/search.
4. Generate signed upload URL for listing image path `listings/{listingId}/...`.
5. Create/open conversation and receive message list.
6. Get package list and create purchase invoice.
7. Verify push notifications and unread counter.
8. Validate admin dashboard numbers update next day via `DailyStatsJob`.
