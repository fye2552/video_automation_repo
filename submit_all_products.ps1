param(
  [string]$Skill = "skill_c",
  [string]$CustomSkillPath = "",
  [int]$GenerateCount = 1,
  [string]$DryRun = "true",
  [int]$N8nPort = 5678,
  [int]$SubmitDelaySeconds = 5
)

$ErrorActionPreference = "Continue"
if ($GenerateCount -ne 1) {
  Write-Host "GenerateCount is forced to 1 for stability." -ForegroundColor Yellow
  $GenerateCount = 1
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$productsDir = Join-Path $root "local_products"
if (-not (Test-Path $productsDir)) {
  throw "local_products directory not found: $productsDir"
}

$products = Get-ChildItem -LiteralPath $productsDir -Directory | Sort-Object Name
if (-not $products) {
  Write-Warning "No product folders found under $productsDir"
  exit 0
}

$dryRunValue = [System.Convert]::ToBoolean($DryRun)
$uploadWebhook = "http://127.0.0.1:$N8nPort/webhook/local-product-upload-github"
$mainWebhook = "http://127.0.0.1:$N8nPort/webhook/main-generate-video"

foreach ($product in $products) {
  $profile = Join-Path $product.FullName "product_profile.yaml"
  if (-not (Test-Path $profile)) {
    Write-Warning "Skipping $($product.Name): product_profile.yaml not found"
    continue
  }

  $uploadBody = @{
    product_id = $product.Name
    active_skill = $Skill
    custom_skill_path = $CustomSkillPath
    generate_count = 1
    dry_run = $dryRunValue
    auto_start_main = $false
  } | ConvertTo-Json

  Write-Host "Uploading product=$($product.Name) to GitHub; auto_start_main=false" -ForegroundColor Cyan
  try {
    $uploadResponse = Invoke-RestMethod `
      -Uri $uploadWebhook `
      -Method Post `
      -ContentType "application/json" `
      -Body $uploadBody `
      -TimeoutSec 300 `
      -ErrorAction Stop
  } catch {
    Write-Warning "Upload failed for $($product.Name): $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Warning $_.ErrorDetails.Message }
    continue
  }

  $githubUrl = [string]$uploadResponse.github_url
  if (-not $githubUrl -and $uploadResponse.body) {
    $githubUrl = [string]$uploadResponse.body.github_url
  }
  if (-not $githubUrl) {
    Write-Warning "Upload response for $($product.Name) did not contain github_url. Main workflow was not submitted."
    $uploadResponse | ConvertTo-Json -Depth 20
    continue
  }

  $mainBody = @{
    github_url = $githubUrl
    active_skill = $Skill
    custom_skill_path = $CustomSkillPath
    generate_count = 1
    dry_run = $dryRunValue
  } | ConvertTo-Json

  Write-Host "Submitting main workflow for product=$($product.Name), github_url=$githubUrl" -ForegroundColor Cyan
  try {
    $mainResponse = Invoke-RestMethod `
      -Uri $mainWebhook `
      -Method Post `
      -ContentType "application/json" `
      -Body $mainBody `
      -TimeoutSec 2400 `
      -ErrorAction Stop

    [pscustomobject]@{
      product_id = $product.Name
      github_url = $githubUrl
      upload_ok = $true
      main_response = $mainResponse
    } | ConvertTo-Json -Depth 30
  } catch {
    Write-Warning "Main workflow submit failed for $($product.Name): $($_.Exception.Message)"
    if ($_.ErrorDetails.Message) { Write-Warning $_.ErrorDetails.Message }
  }

  if ($SubmitDelaySeconds -gt 0) {
    Start-Sleep -Seconds $SubmitDelaySeconds
  }
}
