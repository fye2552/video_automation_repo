[CmdletBinding()]
param(
    [string]$SourceSnapshotPath = ''
)

$ErrorActionPreference = 'Stop'
$apiKey = [Environment]::GetEnvironmentVariable('KALODATA_SECRET_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($apiKey)) { throw 'KALODATA_SECRET_KEY is not configured.' }

$root = Split-Path -Parent $PSScriptRoot
$poolDir = Join-Path $root 'test_logs\kalodata_ai_recent_pool'
if ([string]::IsNullOrWhiteSpace($SourceSnapshotPath)) {
    $source = Get-ChildItem -LiteralPath $poolDir -Filter 't0_kalodata_ai_recent_*.json' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $source) { throw 'No Kalodata T0 snapshot was found.' }
    $SourceSnapshotPath = $source.FullName
}

$snapshot = Get-Content -LiteralPath $SourceSnapshotPath -Raw | ConvertFrom-Json
$excludedVideoIds = @()
Get-ChildItem -LiteralPath $poolDir -Filter 'manual_review_*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $review = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    $excludedVideoIds += @($review.decisions | Where-Object { $_.decision -eq 'excluded' } | ForEach-Object { [string]$_.video_id })
}
$excludedVideoIds = @($excludedVideoIds | Select-Object -Unique)

function Get-RatioOrNull {
    param([Nullable[double]]$Current, [Nullable[double]]$Baseline)
    if ($null -eq $Current -or $null -eq $Baseline -or $Baseline -le 0) { return $null }
    return [Math]::Round($Current / $Baseline, 4)
}

$headers = @{ 'secret-key' = $apiKey; 'Content-Type' = 'application/json' }
$observedAt = [DateTimeOffset]::UtcNow
$records = foreach ($entry in @($snapshot.qualified_candidates | Where-Object { $_.rank.video_id -notin $excludedVideoIds })) {
    $request = @{ region = 'US'; language = 'en-US'; currency = 'USD'; date_range = 'lastDay'; video_id = [string]$entry.rank.video_id; need_extra = $false }
    try {
        $response = Invoke-RestMethod -Method Post -Uri 'https://www.kalodata.com/openapi/v1/tiktok/video/detail' -Headers $headers -Body ($request | ConvertTo-Json -Compress) -TimeoutSec 30
        $t0 = $entry.detail
        $t1 = $response.data
        [pscustomobject]@{
            video_id = [string]$entry.rank.video_id
            source_publish_time_utc = $entry.rank.publish_time_utc
            duration_seconds = $t0.duration
            t0 = [pscustomobject]@{ views = $t0.views; sales_volumn = $t0.sales_volumn; revenue = $t0.revenue; video_gpm = $t0.video_gpm; ad_view_ratio = $t0.ad_view_ratio }
            t1 = [pscustomobject]@{ views = $t1.views; sales_volumn = $t1.sales_volumn; revenue = $t1.revenue; video_gpm = $t1.video_gpm; ad_view_ratio = $t1.ad_view_ratio; ai_video = $t1.ai_video; product_number = $t1.product_number }
            velocity = [pscustomobject]@{
                views = Get-RatioOrNull ([double]$t1.views) ([double]$t0.views)
                sales = Get-RatioOrNull ([double]$t1.sales_volumn) ([double]$t0.sales_volumn)
                revenue = Get-RatioOrNull ([double]$t1.revenue) ([double]$t0.revenue)
                gpm_change = if ($null -ne $t1.video_gpm -and $null -ne $t0.video_gpm) { [Math]::Round(([double]$t1.video_gpm - [double]$t0.video_gpm), 4) } else { $null }
                ad_view_ratio_change = if ($null -ne $t1.ad_view_ratio -and $null -ne $t0.ad_view_ratio) { [Math]::Round(([double]$t1.ad_view_ratio - [double]$t0.ad_view_ratio), 4) } else { $null }
            }
            success = $response.success
            message = $response.message
        }
    } catch {
        [pscustomobject]@{ video_id = [string]$entry.rank.video_id; success = $false; message = $_.Exception.Message }
    }
    Start-Sleep -Milliseconds 250
}

$result = [ordered]@{
    schema_version = 1
    observed_at_utc = $observedAt.ToString('o')
    source_snapshot = (Resolve-Path -LiteralPath $SourceSnapshotPath).Path
    statistic_window = 'lastDay'
    note = 'T0 and T+1 both use Kalodata lastDay. Velocity compares adjacent US-day ranking windows; it is not lifetime cumulative growth.'
    excluded_video_ids = $excludedVideoIds
    records = $records
}
$stamp = $observedAt.ToString('yyyyMMddTHHmmssZ')
$outputPath = Join-Path $poolDir "tplus1_kalodata_review_$stamp.json"
$result | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $outputPath -Encoding utf8

[pscustomobject]@{
    observed_at_utc = $result.observed_at_utc
    source_snapshot = $result.source_snapshot
    reviewed = @($records).Count
    succeeded = @($records | Where-Object { $_.success -eq $true }).Count
    result_file = $outputPath
} | ConvertTo-Json -Compress
