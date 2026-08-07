[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceSnapshotPath
)

$ErrorActionPreference = 'Stop'
$fastMossKey = [Environment]::GetEnvironmentVariable('FASTMOSS_CLIENT_SECRET', 'User')
if ([string]::IsNullOrWhiteSpace($fastMossKey)) { throw 'FASTMOSS_CLIENT_SECRET is not configured.' }

$root = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $root 'runtime\content_radar'
$reconciliationDir = Join-Path $runtimeRoot 'reconciliations'
$eventDir = Join-Path $runtimeRoot 'events'
New-Item -ItemType Directory -Force -Path $reconciliationDir, $eventDir | Out-Null

$snapshotPath = (Resolve-Path -LiteralPath $SourceSnapshotPath).Path
$snapshot = Get-Content -LiteralPath $snapshotPath -Raw | ConvertFrom-Json
$poolDir = Split-Path -Parent $snapshotPath
$excludedVideoIds = @()
Get-ChildItem -LiteralPath $poolDir -Filter 'manual_review_*.json' -File -ErrorAction SilentlyContinue | ForEach-Object {
    $review = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    $excludedVideoIds += @($review.decisions | Where-Object { $_.decision -eq 'excluded' } | ForEach-Object { [string]$_.video_id })
}
$excludedVideoIds = @($excludedVideoIds | Select-Object -Unique)

$headers = @{ Authorization = "Bearer $fastMossKey"; 'Content-Type' = 'application/json' }
$observedAt = [DateTimeOffset]::UtcNow
$sourceKey = [IO.Path]::GetFileNameWithoutExtension($snapshotPath)

$records = foreach ($entry in @($snapshot.qualified_candidates | Where-Object { $_.rank.video_id -notin $excludedVideoIds })) {
    $videoId = [string]$entry.rank.video_id
    $request = @{ filter = @{ region = 'US'; video_id = $videoId }; page = 1; pagesize = 10 }
    $status = 'attention_required'
    $reason = $null
    $fastMossVideo = $null
    try {
        $response = Invoke-RestMethod -Method Post -Uri 'https://openapi.fastmoss.com/video/v1/search' -Headers $headers -Body ($request | ConvertTo-Json -Depth 6) -TimeoutSec 30
        $matches = @($response.data.list | Where-Object { [string]$_.video_id -eq $videoId })
        if ($response.code -ne 0) {
            $reason = "FastMoss error: $($response.message)"
        } elseif ($matches.Count -ne 1) {
            $reason = "FastMoss exact Video ID match count is $($matches.Count), expected 1"
        } elseif ($entry.detail.product_number -lt 1) {
            $reason = 'Kalodata says the video has no associated product'
        } elseif (-not $matches[0].is_ecommerce -or @($matches[0].product_info).Count -lt 1) {
            $reason = 'FastMoss says the video has no e-commerce product information'
        } else {
            $fastMossVideo = $matches[0]
            $status = 'approval_required'
        }
    } catch {
        $reason = "FastMoss request failed: $($_.Exception.Message)"
    }

    $product = if ($null -ne $fastMossVideo) { @($fastMossVideo.product_info)[0] } else { $null }
    [pscustomobject]@{
        event_id = "${sourceKey}_${videoId}"
        event_type = $status
        event_status = 'open'
        observed_at_utc = $observedAt.ToString('o')
        video_id = $videoId
        traffic_source = $entry.traffic_source
        kalodata = [pscustomobject]@{
            publish_time_utc = $entry.rank.publish_time_utc
            ai_video = $entry.detail.ai_video
            product_number = $entry.detail.product_number
            views = $entry.detail.views
            sales_volumn = $entry.detail.sales_volumn
            revenue = $entry.detail.revenue
            ad_view_ratio = $entry.detail.ad_view_ratio
            ads_roas = $entry.detail.ads_roas
        }
        fastmoss = if ($null -ne $fastMossVideo) { [pscustomobject]@{
            video_url = $fastMossVideo.video_url
            create_time = $fastMossVideo.create_time
            create_date = $fastMossVideo.create_date
            is_ecommerce = $fastMossVideo.is_ecommerce
            product = [pscustomobject]@{
                product_id = $product.product_id
                title = $product.title
                detail_url = $product.detail_url
                cover_url = $product.cover
                category_name = $product.category_name
                price = $product.price
            }
        }} else { $null }
        reason = $reason
        next_action = if ($status -eq 'approval_required') { 'Await mobile ChatGPT command: 复刻 <video_id> / 观察 <video_id> / 淘汰 <video_id>' } else { 'User resolution required before production can continue' }
    }
}

$result = [ordered]@{
    observed_at_utc = $observedAt.ToString('o')
    source_snapshot = $snapshotPath
    method = 'Kalodata is source of truth for AI and ranking metrics; FastMoss is exact-video source of truth for product link and image URL.'
    excluded_video_ids = $excludedVideoIds
    records = $records
}
$reconciliationPath = Join-Path $reconciliationDir "reconciliation_$($observedAt.ToString('yyyyMMddTHHmmssZ')).json"
$result | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $reconciliationPath -Encoding utf8

foreach ($record in $records) {
    $eventPath = Join-Path $eventDir "$($record.event_id).json"
    $record | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $eventPath -Encoding utf8
}

[pscustomobject]@{
    observed_at_utc = $result.observed_at_utc
    reconciliation_file = $reconciliationPath
    events_written = @($records).Count
    approval_required = @($records | Where-Object { $_.event_type -eq 'approval_required' }).Count
    attention_required = @($records | Where-Object { $_.event_type -eq 'attention_required' }).Count
    event_files = @($records | ForEach-Object { Join-Path $eventDir "$($_.event_id).json" })
} | ConvertTo-Json -Depth 8
