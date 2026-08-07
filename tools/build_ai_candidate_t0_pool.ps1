[CmdletBinding()]
param(
    [int]$FastMossPageSize = 100,
    [int]$MaxKalodataChecks = 25,
    [int]$CandidateTarget = 15,
    [string]$Region = 'US'
)

$ErrorActionPreference = 'Stop'

function Get-FirstProduct {
    param($ProductInfo)
    if ($null -eq $ProductInfo) { return $null }
    if ($ProductInfo -is [System.Array]) { return @($ProductInfo)[0] }
    return $ProductInfo
}

$fastMossKey = [Environment]::GetEnvironmentVariable('FASTMOSS_CLIENT_SECRET', 'User')
$kalodataKey = [Environment]::GetEnvironmentVariable('KALODATA_SECRET_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($fastMossKey)) { throw 'FASTMOSS_CLIENT_SECRET is not configured.' }
if ([string]::IsNullOrWhiteSpace($kalodataKey)) { throw 'KALODATA_SECRET_KEY is not configured.' }

$root = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $root 'test_logs\ai_video_candidate_pool'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$observedAt = (Get-Date).ToUniversalTime()
$now = [DateTimeOffset]$observedAt
$fastMossHeaders = @{ Authorization = "Bearer $fastMossKey"; 'Content-Type' = 'application/json' }
$fastMossRequest = @{
    filter = @{
        region = $Region
        is_ecommerce = 1
        create_time_range = @{
            min = $now.AddHours(-48).ToUnixTimeSeconds()
            max = $now.ToUnixTimeSeconds()
        }
    }
    orderby = @(@{ field = 'units_sold'; order = 'desc' })
    page = 1
    pagesize = $FastMossPageSize
}
$fastMossResponse = Invoke-RestMethod -Method Post -Uri 'https://openapi.fastmoss.com/video/v1/search' -Headers $fastMossHeaders -Body ($fastMossRequest | ConvertTo-Json -Depth 8) -TimeoutSec 30
if ($fastMossResponse.code -ne 0) { throw "FastMoss video search failed: $($fastMossResponse.message)" }

# Conservative textual screen: this is a compliance pre-filter, not a legal claim review.
$efficacyRiskPattern = 'supplement|vitamin|collagen|weight.?loss|slim|therapy|treatment|acne|fungal|folliculitis|hyperpigmentation|medical|healing|repair|anti.?aging|pain.?relief|detox|whiten|brighten|exfoliat|pore.?clogg|serum|skin.?care'
$preCandidates = @(
    $fastMossResponse.data.list |
        Where-Object { $_.is_ecommerce -eq 1 -and $_.is_ad -eq 0 -and [double]$_.units_sold -gt 0 -and $null -ne $_.product_info } |
        ForEach-Object {
            $product = Get-FirstProduct $_.product_info
            [pscustomobject]@{
                video_id = [string]$_.video_id
                video_url = $_.video_url
                create_time = $_.create_time
                create_date = $_.create_date
                fastmoss_play_count = [Int64]$_.play_count
                fastmoss_digg_count = [Int64]$_.digg_count
                fastmoss_share_count = [Int64]$_.share_count
                fastmoss_comment_count = [Int64]$_.comment_count
                fastmoss_interact_rate = $_.interact_rate
                fastmoss_units_sold = [Int64]$_.units_sold
                fastmoss_gmv = [double]$_.gmv
                product_id = [string]$product.product_id
                product_title = [string]$product.title
                product_category = [string]$product.category_name
                product_url = $product.detail_url
                excluded_by_compliance_prefilter = ([string]$product.title -match $efficacyRiskPattern)
            }
        } |
        Where-Object { -not $_.excluded_by_compliance_prefilter } |
        Sort-Object fastmoss_units_sold -Descending |
        Select-Object -First $MaxKalodataChecks
)

$kalodataHeaders = @{ 'secret-key' = $kalodataKey; 'Content-Type' = 'application/json' }
$checked = foreach ($candidate in $preCandidates) {
    $detailRequest = @{ region = $Region; language = 'en-US'; currency = 'USD'; date_range = 'lastDay'; video_id = $candidate.video_id; need_extra = $false }
    try {
        $detail = Invoke-RestMethod -Method Post -Uri 'https://www.kalodata.com/openapi/v1/tiktok/video/detail' -Headers $kalodataHeaders -Body ($detailRequest | ConvertTo-Json -Compress) -TimeoutSec 30
        [pscustomobject]@{
            candidate = $candidate
            kalodata_success = $detail.success
            kalodata_code = $detail.code
            kalodata_message = $detail.message
            kalodata = $detail.data
        }
    } catch {
        [pscustomobject]@{
            candidate = $candidate
            kalodata_success = $false
            kalodata_code = $null
            kalodata_message = $_.Exception.Message
            kalodata = $null
        }
    }
    Start-Sleep -Milliseconds 250
}

$qualified = @(
    $checked |
        Where-Object { $_.kalodata_success -eq $true -and $_.kalodata.ai_video -eq 1 -and $_.kalodata.product_number -ge 1 } |
        Sort-Object { $_.candidate.fastmoss_units_sold } -Descending |
        Select-Object -First $CandidateTarget
)

$snapshot = [ordered]@{
    schema_version = 1
    observed_at_utc = $observedAt.ToString('o')
    strategy = 'FastMoss discovers fresh natural e-commerce videos and attached products; Kalodata confirms ai_video=1. This file is T0 for next-day fixed-ID comparison.'
    criteria = [ordered]@{
        region = $Region
        create_time_window_hours = 48
        natural_video_only = $true
        positive_units_sold_required = $true
        compliance_prefilter = 'exclude title keywords suggesting efficacy or medical claims'
        kalodata_ai_video_required = $true
        kalodata_product_number_min = 1
    }
    source_counts = [ordered]@{
        fastmoss_returned = @($fastMossResponse.data.list).Count
        prefiltered_before_kalodata = @($preCandidates).Count
        kalodata_checked = @($checked).Count
        kalodata_ai_qualified = @($qualified).Count
    }
    qualified_candidates = $qualified
    rejected_or_unverified = @($checked | Where-Object { $_ -notin $qualified } | ForEach-Object {
        [pscustomobject]@{
            video_id = $_.candidate.video_id
            product_title = $_.candidate.product_title
            fastmoss_units_sold = $_.candidate.fastmoss_units_sold
            kalodata_success = $_.kalodata_success
            kalodata_ai_video = if ($null -ne $_.kalodata) { $_.kalodata.ai_video } else { $null }
            reason = if (-not $_.kalodata_success) { 'Kalodata detail unavailable' } elseif ($_.kalodata.ai_video -ne 1) { 'Kalodata ai_video is not 1' } elseif ($_.kalodata.product_number -lt 1) { 'Kalodata product_number is zero' } else { 'not selected after ranking' }
        }
    })
}

$stamp = $observedAt.ToString('yyyyMMddTHHmmssZ')
$snapshotPath = Join-Path $outputDir "t0_ai_video_candidates_$stamp.json"
$snapshot | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $snapshotPath -Encoding utf8

[pscustomobject]@{
    observed_at_utc = $snapshot.observed_at_utc
    result_file = $snapshotPath
    fastmoss_returned = $snapshot.source_counts.fastmoss_returned
    prefiltered = $snapshot.source_counts.prefiltered_before_kalodata
    kalodata_checked = $snapshot.source_counts.kalodata_checked
    ai_qualified = $snapshot.source_counts.kalodata_ai_qualified
    qualified_video_ids = @($qualified | ForEach-Object { $_.candidate.video_id })
} | ConvertTo-Json -Depth 6
