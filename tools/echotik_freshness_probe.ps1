[CmdletBinding()]
param(
    [string]$Region = 'US',
    [int]$PageSize = 10
)

$ErrorActionPreference = 'Stop'

$apiUsername = [Environment]::GetEnvironmentVariable('ECHOTIK_API_USERNAME', 'User')
$apiPassword = [Environment]::GetEnvironmentVariable('ECHOTIK_API_PASSWORD', 'User')
if ([string]::IsNullOrWhiteSpace($apiUsername) -or [string]::IsNullOrWhiteSpace($apiPassword)) {
    throw 'EchoTik API credentials are not configured for the current Windows user.'
}

$credentialPair = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$apiUsername`:$apiPassword"))
$headers = @{ Authorization = "Basic $credentialPair" }

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $workspaceRoot 'test_logs\echotik_freshness_probe'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$watchlistPath = Join-Path $outputDir 'watchlist.json'
$observedAt = [DateTimeOffset]::UtcNow
$timestamp = $observedAt.ToString('yyyyMMddTHHmmssZ')

$discoveryUri = "https://open.echotik.live/api/v2/video/list?region=$Region&sales_flag=1&sort_type=1&video_sort_field=2&page_num=1&page_size=$PageSize"

try {
    $discoveryResponse = Invoke-RestMethod -Method Get -Uri $discoveryUri -Headers $headers -TimeoutSec 30
    if ($discoveryResponse.code -ne 0) {
        throw "EchoTik video-list API returned code $($discoveryResponse.code): $($discoveryResponse.message)"
    }

    if (Test-Path $watchlistPath) {
        $watchlist = Get-Content -Raw $watchlistPath | ConvertFrom-Json
        $videoIds = @($watchlist.video_ids)
    } else {
        $videoIds = @($discoveryResponse.data | ForEach-Object { [string]$_.video_id } | Where-Object { $_ })
        if ($videoIds.Count -eq 0) {
            throw 'EchoTik video-list API returned no video IDs for the initial watchlist.'
        }
        [ordered]@{
            created_at_utc = $observedAt.ToString('o')
            region = $Region
            video_ids = $videoIds
        } | ConvertTo-Json | Set-Content -LiteralPath $watchlistPath -Encoding utf8
    }

    $detailUri = "https://open.echotik.live/api/v2/video/detail?video_ids=$([uri]::EscapeDataString(($videoIds -join ',')))"
    $detailResponse = Invoke-RestMethod -Method Get -Uri $detailUri -Headers $headers -TimeoutSec 30
    if ($detailResponse.code -ne 0) {
        throw "EchoTik detail API returned code $($detailResponse.code): $($detailResponse.message)"
    }
} catch {
    $failure = [ordered]@{
        observed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
        region = $Region
        error = $_.Exception.Message
    }
    $failure | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDir "probe_failure_$timestamp.json") -Encoding utf8
    throw
}

$record = [ordered]@{
    observed_at_utc = $observedAt.ToString('o')
    region = $Region
    watched_video_ids = $videoIds
    discovery_response = $discoveryResponse
    detail_response = $detailResponse
}
$outputPath = Join-Path $outputDir "probe_snapshot_$timestamp.json"
$record | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $outputPath -Encoding utf8

[pscustomobject]@{
    observed_at_utc = $record.observed_at_utc
    watched_videos = $videoIds.Count
    discovered_videos = @($discoveryResponse.data).Count
    detail_videos = @($detailResponse.data).Count
    result_file = $outputPath
} | ConvertTo-Json -Compress
