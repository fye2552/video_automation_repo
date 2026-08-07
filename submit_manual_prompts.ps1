param(
  [string]$PromptRoot = (Join-Path $PSScriptRoot 'manual_prompts\pending'),
  [string]$ArchiveRoot = (Join-Path $PSScriptRoot 'manual_prompts\submitted'),
  [string]$ProductsRoot = (Join-Path $PSScriptRoot 'local_products'),
  [int]$N8nPort = 5678,
  [switch]$DryRun,
  [switch]$KeepSubmittedFiles
)

$ErrorActionPreference = 'Stop'
$uploadWebhook = "http://127.0.0.1:$N8nPort/webhook/local-product-upload-github"
$manualWebhook = "http://127.0.0.1:$N8nPort/webhook/manual-prompt-generate-video"

if (-not (Test-Path -LiteralPath $PromptRoot)) {
  New-Item -ItemType Directory -Force -Path $PromptRoot | Out-Null
}
if (-not (Test-Path -LiteralPath $ArchiveRoot)) {
  New-Item -ItemType Directory -Force -Path $ArchiveRoot | Out-Null
}
if (-not (Test-Path -LiteralPath $ProductsRoot)) {
  throw "Product root was not found: $ProductsRoot"
}

$promptFiles = Get-ChildItem -LiteralPath $PromptRoot -File -Filter '*.txt' | Sort-Object Name
if (-not $promptFiles) {
  Write-Host "No .txt prompts found in: $PromptRoot" -ForegroundColor Yellow
  exit 0
}

foreach ($promptFile in $promptFiles) {
  $productId = [System.IO.Path]::GetFileNameWithoutExtension($promptFile.Name).Trim()
  if ($productId -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
    Write-Warning "Skipping $($promptFile.Name): its name is not a safe product_id. Use letters, numbers, underscores, or hyphens only."
    continue
  }

  $productDir = Join-Path $ProductsRoot $productId
  if (-not (Test-Path -LiteralPath $productDir -PathType Container)) {
    Write-Warning "Skipping $($promptFile.Name): matching product directory not found: $productDir"
    continue
  }

  $promptText = Get-Content -LiteralPath $promptFile.FullName -Raw -Encoding UTF8
  $promptBlocks = @($promptText -split '(?m)^\s*={3,}\s*$' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  if ($promptBlocks.Count -eq 0) {
    Write-Warning "Skipping $($promptFile.Name): no prompt text found. Separate multiple videos with a line containing only ===."
    continue
  }

  try {
    $uploadBody = @{
      product_id = $productId
      active_skill = 'skill_c'
      custom_skill_path = ''
      generate_count = 1
      dry_run = [bool]$DryRun
      auto_start_main = $false
    } | ConvertTo-Json -Depth 10

    Write-Host "Uploading only the matching product: $productId" -ForegroundColor Cyan
    $uploadResponse = Invoke-RestMethod -Uri $uploadWebhook -Method Post -ContentType 'application/json' -Body $uploadBody -TimeoutSec 300
    $githubUrl = [string]$uploadResponse.github_url
    if (-not $githubUrl -and $uploadResponse.body) { $githubUrl = [string]$uploadResponse.body.github_url }
    if (-not $githubUrl) { throw 'Upload response did not include github_url.' }

    $uploadedImages = @($uploadResponse.uploaded_images)
    if (-not $uploadedImages.Count -and $uploadResponse.body) { $uploadedImages = @($uploadResponse.body.uploaded_images) }
    if (-not $uploadedImages.Count) {
      throw 'Upload response contains no uploaded_images. Add product images before using manual prompts.'
    }

    $manualBody = @{
      product_id = $productId
      github_url = $githubUrl
      uploaded_images = $uploadedImages
      prompt_blocks = $promptBlocks
      source_prompt_file = $promptFile.FullName
      duration = '10'
      ratio = '9:16'
      dry_run = [bool]$DryRun
    } | ConvertTo-Json -Depth 20

    Write-Host "Submitting $($promptBlocks.Count) manual video prompt block(s) for $productId" -ForegroundColor Cyan
    $manualResponse = Invoke-RestMethod -Uri $manualWebhook -Method Post -ContentType 'application/json' -Body $manualBody -TimeoutSec 2400
    $manualResponse | ConvertTo-Json -Depth 30

    if (-not $DryRun -and -not $KeepSubmittedFiles) {
      $archivePath = Join-Path $ArchiveRoot $promptFile.Name
      if (Test-Path -LiteralPath $archivePath) {
        $archivePath = Join-Path $ArchiveRoot ("{0}_{1}.txt" -f $productId, (Get-Date -Format 'yyyyMMdd_HHmmss'))
      }
      Move-Item -LiteralPath $promptFile.FullName -Destination $archivePath
      Write-Host "Moved submitted prompt file to: $archivePath" -ForegroundColor Green
    }
  } catch {
    Write-Warning "Manual prompt submission failed for ${productId}: $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Warning $_.ErrorDetails.Message }
    Write-Warning "The prompt file stays in the pending folder so it can be corrected and retried."
  }
}
