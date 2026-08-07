[CmdletBinding()]
param(
    [string]$Region = 'US',
    [int]$LookbackHours = 72,
    [int]$PageSize = 10,
    [int]$ProductCategoryId
)

$ErrorActionPreference = 'Stop'

$apiKey = [Environment]::GetEnvironmentVariable('FASTMOSS_CLIENT_SECRET', 'User')
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'FASTMOSS_CLIENT_SECRET is not configured for the current Windows user.'
}

$now = [DateTimeOffset]::UtcNow
$createRange = @{
    min = $now.AddHours(-$LookbackHours).ToUnixTimeSeconds()
    max = $now.ToUnixTimeSeconds()
}

$filter = @{
    region = $Region
    is_ecommerce = $true
    create_time_range = $createRange
}
if ($PSBoundParameters.ContainsKey('ProductCategoryId')) {
    $filter.product_category_id = $ProductCategoryId
}

$request = @{
    filter = $filter
    orderby = @(@{ field = 'create_time'; order = 'desc' })
    page = 1
    pagesize = $PageSize
    lang = 'EN_US'
}

$headers = @{
    Authorization = "Bearer $apiKey"
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $workspaceRoot 'test_logs\fastmoss_freshness_probe'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$timestamp = $now.ToString('yyyyMMddTHHmmssZ')

try {
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri 'https://openapi.fastmoss.com/video/v1/search' `
        -Headers $headers `
        -ContentType 'application/json' `
        -Body ($request | ConvertTo-Json -Depth 8 -Compress) `
        -TimeoutSec 30
} catch {
    $failure = [ordered]@{
        observed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
        endpoint = '/video/v1/search'
        request = $request
        error = $_.Exception.Message
    }
    $failure | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $outputDir "video_failure_$timestamp.json") -Encoding utf8
    throw
}

$record = [ordered]@{
    observed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    endpoint = '/video/v1/search'
    request = $request
    response = $response
}
$outputPath = Join-Path $outputDir "video_snapshot_$timestamp.json"
$record | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $outputPath -Encoding utf8

[pscustomobject]@{
    observed_at_utc = $record.observed_at_utc
    response_timestamp = $response.timestamp
    code = $response.code
    message = $response.message
    returned_videos = @($response.data.list).Count
    result_file = $outputPath
} | ConvertTo-Json -Compress
