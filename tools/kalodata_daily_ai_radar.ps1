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
    discovery = $discovery
    reconciliation = $reconciliation
} | ConvertTo-Json -Depth 10
