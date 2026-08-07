[CmdletBinding()]
param(
    [ValidateSet('ProbeRank', 'ProbeDetail')]
    [string]$Action = 'ProbeRank',
    [string]$Region = 'US',
    [string]$Language = 'en-US',
    [string]$Currency = 'USD',
    [string]$DateRange = 'last7Day',
    [int]$PageNumber = 1,
    [string]$VideoId
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-TikTokVideoIdPublishTime {
    param([Parameter(Mandatory)][string]$VideoId)

    $unixSeconds = [UInt64]$VideoId -shr 32
    return [DateTimeOffset]::FromUnixTimeSeconds([Int64]$unixSeconds)
}

$apiKey = [Environment]::GetEnvironmentVariable('KALODATA_SECRET_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'KALODATA_SECRET_KEY is not configured for the current Windows user.'
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $workspaceRoot 'test_logs\kalodata_freshness_probe'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$request = @{
    region     = $Region
    language   = $Language
    currency   = $Currency
    date_range = $DateRange
}

if ($Action -eq 'ProbeRank') {
    $endpoint = '/openapi/v1/tiktok/video/rank'
    $request.page_number = $PageNumber
} else {
    if ([string]::IsNullOrWhiteSpace($VideoId)) {
        throw 'VideoId is required when Action is ProbeDetail.'
    }
    $endpoint = '/openapi/v1/tiktok/video/detail'
    $request.video_id = $VideoId
    $request.need_extra = $false
}

$headers = @{
    'secret-key' = $apiKey
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri "https://www.kalodata.com$endpoint" `
        -Headers $headers `
        -Body ($request | ConvertTo-Json -Compress) `
        -TimeoutSec 30
} catch {
    $httpStatus = $null
    $serverMessage = $null
    if ($null -ne $_.Exception.Response) {
        $httpStatus = [int]$_.Exception.Response.StatusCode
        $stream = $_.Exception.Response.GetResponseStream()
        if ($null -ne $stream) {
            $reader = New-Object System.IO.StreamReader($stream)
            $serverMessage = $reader.ReadToEnd()
            $reader.Dispose()
        }
    }
    $failure = [ordered]@{
        observed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        action = $Action
        endpoint = $endpoint
        request = $request
        http_status = $httpStatus
        error = $_.Exception.Message
        server_message = $serverMessage
    }
    $failure | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDir "rank_failure_$timestamp.json") -Encoding utf8
    throw
}

$record = [ordered]@{
    observed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    action = $Action
    endpoint = $endpoint
    request = $request
    response = $response
}

if ($Action -eq 'ProbeRank') {
    $record.derived_video_publish_times = @($response.data | ForEach-Object {
        $publishedAt = ConvertFrom-TikTokVideoIdPublishTime -VideoId ([string]$_.video_id)
        [ordered]@{
            video_id = [string]$_.video_id
            publish_time_utc = $publishedAt.ToString('o')
            publish_time_us_pacific = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($publishedAt, 'Pacific Standard Time').ToString('o')
        }
    })
} else {
    $publishedAt = ConvertFrom-TikTokVideoIdPublishTime -VideoId ([string]$response.data.video_id)
    $record.derived_video_publish_times = @([ordered]@{
        video_id = [string]$response.data.video_id
        publish_time_utc = $publishedAt.ToString('o')
        publish_time_us_pacific = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($publishedAt, 'Pacific Standard Time').ToString('o')
    })
}

$outputPath = Join-Path $outputDir "rank_snapshot_$timestamp.json"
$record | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $outputPath -Encoding utf8

[pscustomobject]@{
    observed_at_utc = $record.observed_at_utc
    endpoint = $record.endpoint
    result_file = $outputPath
    success = $response.success
    code = $response.code
    message = $response.message
} | ConvertTo-Json -Compress
