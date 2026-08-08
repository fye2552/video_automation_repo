[CmdletBinding()]
param(
    [int]$MaxPages = 10,
    [int]$CandidateTarget = 15
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$poolDir = Join-Path $root 'test_logs\kalodata_ai_recent_pool'
$t0Files = @(Get-ChildItem -LiteralPath $poolDir -Filter 't0_kalodata_ai_recent_*.json' -File -ErrorAction SilentlyContinue)

# Stage 1 must run before discovery so the latest existing T0 is yesterday's fixed-ID pool.
$review = $null
if ($t0Files.Count -gt 0) {
    $reviewRaw = & (Join-Path $PSScriptRoot 'kalodata_tplus1_review.ps1')
    $review = $reviewRaw | ConvertFrom-Json
}

# Surface the actual T+1 decision records to the scheduled task. A count alone
# cannot tell the mobile operator which video needs a replication decision.
$reviewDecisions = @()
if ($null -ne $review -and $review.result_file -and (Test-Path -LiteralPath $review.result_file)) {
    $reviewData = Get-Content -LiteralPath $review.result_file -Raw | ConvertFrom-Json
    $reviewDecisions = @($reviewData.records | ForEach-Object {
        [pscustomobject]@{
            video_id = $_.video_id
            decision = $_.decision
            reason = $_.reason
            reason_codes = $_.reason_codes
            traffic_source = $_.traffic_source
            t1_views = $_.t1.views
            t1_sales = $_.t1.sales_volumn
            t1_revenue = $_.t1.revenue
            view_retention = $_.velocity.views
            sales_retention = $_.velocity.sales
        }
    })
}

# Stage 2 creates today's new baseline after the prior baseline has been reviewed.
$discoveryRaw = & (Join-Path $PSScriptRoot 'kalodata_ai_recent_t0_pool.ps1') -MaxPages $MaxPages -CandidateTarget $CandidateTarget
$discovery = $discoveryRaw | ConvertFrom-Json

# Stage 3 reconciles the newly created T0 against FastMoss and writes actionable events.
$reconciliationRaw = & (Join-Path $PSScriptRoot 'reconcile_kalodata_fastmoss.ps1') -SourceSnapshotPath $discovery.result_file
$reconciliation = $reconciliationRaw | ConvertFrom-Json

[pscustomobject]@{
    observed_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    sequence = @('review_previous_t0', 'discover_current_t0', 'reconcile_new_t0_with_fastmoss')
    review = $review
    review_decisions = $reviewDecisions
    discovery = $discovery
    reconciliation = $reconciliation
} | ConvertTo-Json -Depth 10
