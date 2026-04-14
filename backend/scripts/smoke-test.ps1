param(
    [string]$BaseUrl = "http://localhost:5000",
    [string]$Email = "phase9_smoke@example.com",
    [string]$Phone = "0901234567",
    [string]$Password = "Password@123"
)

$ErrorActionPreference = "Stop"

function Invoke-Api {
    param(
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [string]$Token = ""
    )

    $headers = @{}
    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }

    $params = @{
        Method = $Method
        Uri = "$BaseUrl$Path"
        Headers = $headers
        ContentType = "application/json"
    }

    if ($null -ne $Body) {
        $params["Body"] = ($Body | ConvertTo-Json -Depth 10)
    }

    return Invoke-RestMethod @params
}

Write-Host "Running smoke test against $BaseUrl" -ForegroundColor Cyan

$register = $null
try {
    $register = Invoke-Api -Method POST -Path "/api/auth/register" -Body @{
        fullName = "Smoke Test User"
        email = $Email
        phone = $Phone
        password = $Password
    }
} catch {
    Write-Host "Register failed (likely existing user), fallback to login." -ForegroundColor Yellow
}

$login = Invoke-Api -Method POST -Path "/api/auth/login" -Body @{
    email = $Email
    password = $Password
}

if (-not $login.success) {
    throw "Login failed."
}

$accessToken = $login.data.accessToken
$refreshToken = $login.data.refreshToken

$refresh = Invoke-Api -Method POST -Path "/api/auth/refresh-token" -Body @{
    refreshToken = $refreshToken
}
if (-not $refresh.success) {
    throw "Refresh token failed."
}

$listings = Invoke-Api -Method GET -Path "/api/listings"
if (-not $listings.success) {
    throw "List listings failed."
}

$packages = Invoke-Api -Method GET -Path "/api/packages"
if (-not $packages.success) {
    throw "Get packages failed."
}

$conversations = Invoke-Api -Method GET -Path "/api/conversations" -Token $accessToken
if (-not $conversations.success) {
    throw "Get conversations failed."
}

Write-Host "Smoke test passed." -ForegroundColor Green
