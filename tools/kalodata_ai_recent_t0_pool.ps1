[CmdletBinding()]
param(
    [int]$MaxPages = 10,
    [int]$PageSize = 100,
    [int]$MaxAgeHours = 48,
    [int]$CandidateTarget = 15,
    [double]$MaxAdViewRatio = 25,
    [double]$MinAdsRoas = 2.6,
    [string]$Region = 'US'
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-TikTokVideoIdPublishTime {
    param([Parameter(Mandatory)][string]$VideoId)
    [DateTimeOffset]::FromUnixTimeSeconds([Int64]([UInt64]$VideoId -shr 32))
}

$apiKey = [Environment]::GetEnvironmentVariable('KALODATA_SECRET_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($apiKey)) { throw 'KALODATA_SECRET_KEY is not configured.' }

$root = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $root 'test_logs\kalodata_ai_recent_pool'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$observedAt = [DateTimeOffset]::UtcNow
$headers = @{ 'secret-key' = $apiKey; 'Content-Type' = 'application/json' }
$rankResults = @()

for ($page = 1; $page -le $MaxPages; $page++) {
    $request = @{
        region = $Region
        language = 'en-US'
        currency = 'USD'
        date_range = 'lastDay'
        page_number = $page
        page_size = $PageSize
        is_ai_video = 1
    }
    $response = Invoke-RestMethod -Method Post -Uri 'https://www.kalodata.com/openapi/v1/tiktok/video/rank' -Headers $headers -Body ($request | ConvertTo-Json -Compress) -TimeoutSec 30
    if ($response.success -ne $true) { throw "Kalodata rank failed on page ${page}: $($response.code) $($response.message)" }
    $rankResults += @($response.data | ForEach-Object {
        $publishedAt = ConvertFrom-TikTokVideoIdPublishTime ([string]$_.video_id)
        [pscustomobject]@{
            video_id = [string]$_.video_id
            publish_time_utc = $publishedAt.ToString('o')
            age_hours = [Math]::Round(($observedAt - $publishedAt).TotalHours, 2)
            rank_page = $page
            rank_revenue_last_day = $_.revenue
            rank_views_last_day = $_.views
            rank_revenue_growth_rate = $_.revenue_growth_rate
            rank_digg_count = $_.digg_count
            rank_share_count = $_.share_count
            rank_comment_count = $_.comment_count
            rank_ad = $_.ad
            rank_ad_revenue_ratio = $_.ad_revenue_ratio
            rank_ad_view_ratio = $_.ad_view_ratio
            video_title = $_.video_title
            creator_id = $_.belonged_creator.creator_id
            creator_nickname = $_.belonged_creator.nickname
        }
    })
}

$recentAI = @(
    $rankResults |
        Group-Object video_id |
        ForEach-Object { $_.Group[0] } |
        Where-Object { $_.age_hours -ge 0 -and $_.age_hours -le $MaxAgeHours } |
        Sort-Object rank_revenue_last_day -Descending
)

$detailed = foreach ($candidate in $recentAI) {
    $detailRequest = @{ region = $Region; language = 'en-US'; currency = 'USD'; date_range = 'lastDay'; video_id = $candidate.video_id; need_extra = $false }
    try {
        $detail = Invoke-RestMethod -Method Post -Uri 'https://www.kalodata.com/openapi/v1/tiktok/video/detail' -Headers $headers -Body ($detailRequest | ConvertTo-Json -Compress) -TimeoutSec 30
        [pscustomobject]@{ rank = $candidate; detail_success = $detail.success; detail = $detail.data; detail_message = $detail.message }
    } catch {
        [pscustomobject]@{ rank = $candidate; detail_success = $false; detail = $null; detail_message = $_.Exception.Message }
    }
    Start-Sleep -Milliseconds 250
}

# Two eligible routes: natural distribution, or low-ad-ratio paid distribution with efficient ROAS.
$baseEligible = @($detailed | Where-Object { $_.detail_success -eq $true -and $_.detail.ai_video -eq 1 -and $_.detail.product_number -ge 1 })
$naturalCandidates = @($baseEligible | Where-Object { $_.rank.rank_ad -eq 0 } | ForEach-Object { $_ | Add-Member -NotePropertyName traffic_source -NotePropertyValue 'natural' -Force -PassThru })
$efficientPaidCandidates = @($baseEligible | Where-Object {
    $_.rank.rank_ad -eq 1 -and
    $null -ne $_.detail.ad_view_ratio -and [double]$_.detail.ad_view_ratio -le $MaxAdViewRatio -and
    $null -ne $_.detail.ads_roas -and [double]$_.detail.ads_roas -ge $MinAdsRoas
} | ForEach-Object { $_ | Add-Member -NotePropertyName traffic_source -NotePropertyValue 'efficient_paid' -Force -PassThru })

$qualified = @(
    @($naturalCandidates + $efficientPaidCandidates) |
        Sort-Object @{ Expression = { if ($_.traffic_source -eq 'natural') { 0 } else { 1 } } }, @{ Expression = { $_.rank.rank_revenue_last_day }; Descending = $true } |
        Select-Object -First $CandidateTarget
)

$snapshot = [ordered]@{
    schema_version = 1
    observed_at_utc = $observedAt.ToString('o')
    strategy = 'Kalodata AI video rank discovery: is_ai_video=1; TikTok video ID derives publish time; video detail confirms product association. T0 accepts natural videos and efficient low-ad-ratio paid videos as separate traffic sources.'
    criteria = [ordered]@{
        region = $Region
        rank_date_range = 'lastDay'
        is_ai_video = 1
        max_publish_age_hours = $MaxAgeHours
        product_number_min = 1
        natural_route = 'ad=0'
        efficient_paid_route = "ad=1 AND ad_view_ratio <= $MaxAdViewRatio AND ads_roas >= $MinAdsRoas"
    }
    counts = [ordered]@{
        rank_records_scanned = @($rankResults).Count
        ai_videos_published_within_window = @($recentAI).Count
        detail_checked = @($detailed).Count
        qualified_natural_ai_ecommerce_videos = @($naturalCandidates).Count
        qualified_efficient_paid_ai_ecommerce_videos = @($efficientPaidCandidates).Count
        qualified_total = @($qualified).Count
    }
    qualified_candidates = $qualified
    all_recent_ai_videos = $detailed
}

$stamp = $observedAt.ToString('yyyyMMddTHHmmssZ')
$outputPath = Join-Path $outputDir "t0_kalodata_ai_recent_$stamp.json"
$snapshot | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $outputPath -Encoding utf8

[pscustomobject]@{
    observed_at_utc = $snapshot.observed_at_utc
    result_file = $outputPath
    rank_records_scanned = $snapshot.counts.rank_records_scanned
    recent_ai_videos = $snapshot.counts.ai_videos_published_within_window
    qualified_natural_ai_ecommerce_videos = $snapshot.counts.qualified_natural_ai_ecommerce_videos
    qualified_efficient_paid_ai_ecommerce_videos = $snapshot.counts.qualified_efficient_paid_ai_ecommerce_videos
    qualified_total = $snapshot.counts.qualified_total
    qualified_video_ids = @($qualified | ForEach-Object { $_.rank.video_id })
} | ConvertTo-Json -Depth 5
