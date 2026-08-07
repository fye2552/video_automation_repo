[CmdletBinding()]
param(
    [string]$Region = 'US',
    [int]$MaxSnapshots = 9,
    [string[]]$VideoIds = @(
        '7666138519575743757',
        '7665435149047205134',
        '7667204223561485598'
    )
)

$ErrorActionPreference = 'Stop'

$apiUsername = [Environment]::GetEnvironmentVariable('ECHOTIK_API_USERNAME', 'User')
$apiPassword = [Environment]::GetEnvironmentVariable('ECHOTIK_API_PASSWORD', 'User')
if ([string]::IsNullOrWhiteSpace($apiUsername) -or [string]::IsNullOrWhiteSpace($apiPassword)) {
    throw 'EchoTik API credentials are not configured for the current Windows user.'
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $workspaceRoot 'test_logs\echotik_rt_freshness_probe'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$existingSnapshots = @(Get-ChildItem -LiteralPath $outputDir -Filter 'rt_snapshot_*.json' -File -ErrorAction SilentlyContinue)
if ($existingSnapshots.Count -ge $MaxSnapshots) {
    [pscustomobject]@{
        status = 'complete'
        snapshots = $existingSnapshots.Count
        max_snapshots = $MaxSnapshots
        api_requests_made = 0
    } | ConvertTo-Json -Compress
    exit 0
}

$observedAt = [DateTimeOffset]::UtcNow
$timestamp = $observedAt.ToString('yyyyMMddTHHmmssZ')
$credentialPair = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$apiUsername`:$apiPassword"))
$headers = @{ Authorization = "Basic $credentialPair" }

try {
    $videos = foreach ($videoId in $VideoIds) {
        $uri = "https://open.echotik.live/api/v2/rt/video/detail?video_id=$([uri]::EscapeDataString($videoId))&region=$([uri]::EscapeDataString($Region))"
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers -TimeoutSec 30
        if ($response.code -ne 0 -or $null -eq $response.data) {
            throw "EchoTik RT video detail returned code $($response.code): $($response.message) for video $videoId"
        }

        $data = $response.data
        [ordered]@{
            video_id = [string]$data.video_id
            create_time = $data.create_time
            play_count = $data.play_count
            digg_count = $data.digg_count
            comment_count = $data.comment_count
            share_count = $data.share_count
            collect_count = $data.collect_count
            duration = $data.duration
            is_ec_video = $data.is_ec_video
            is_ads = $data.is_ads
        }
    }
} catch {
    [ordered]@{
        observed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
        region = $Region
        error = $_.Exception.Message
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDir "rt_failure_$timestamp.json") -Encoding utf8
    throw
}

$record = [ordered]@{
    observed_at_utc = $observedAt.ToString('o')
    region = $Region
    experiment = 'RT endpoint timeliness validation; three active e-commerce control videos; not a category-selection test.'
    videos = @($videos)
}
$outputPath = Join-Path $outputDir "rt_snapshot_$timestamp.json"
$record | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding utf8

[pscustomobject]@{
    status = 'recorded'
    observed_at_utc = $record.observed_at_utc
    snapshots_after_run = $existingSnapshots.Count + 1
    max_snapshots = $MaxSnapshots
    tracked_videos = @($videos).Count
    api_requests_made = @($videos).Count
    result_file = $outputPath
} | ConvertTo-Json -Compress
