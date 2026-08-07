param(
  [switch]$RunCreateTest,
  [string]$EnvPath = "E:/n8n-video-gemini/.env",
  [string]$PromptImage = "https://raw.githubusercontent.com/fye2552/video_automation_repo/main/products/grout_cleaner_kit_with_stand-up_brush_clean_tile_floors_without_kneeling_profess/skill_a/reference_images/product_white_bg.jpeg",
  [string]$PromptText = "Show the product clearly in one simple shot."
)

$ErrorActionPreference = "Continue"

function Read-DotEnv {
  param([string]$Path)
  $map = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Warning ".env not found: $Path"
    return $map
  }

  Get-Content -LiteralPath $Path -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    $value = $value.Trim('"').Trim("'")
    $map[$key] = $value
    if (-not [Environment]::GetEnvironmentVariable($key, 'Process')) {
      [Environment]::SetEnvironmentVariable($key, $value, 'Process')
    }
  }
  return $map
}

function Get-EnvValue {
  param([hashtable]$DotEnv, [string]$Name, [string]$Default = "")
  $processValue = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ($processValue) { return $processValue }
  if ($DotEnv.ContainsKey($Name)) { return $DotEnv[$Name] }
  return $Default
}

function Join-ApiUrl {
  param([string]$BaseUrl, [string]$Path)
  $base = [string]$BaseUrl
  $pathValue = [string]$Path
  $base = $base.Trim().TrimEnd('/')
  $pathValue = $pathValue.Trim()
  if (-not $base) { throw "MOYIN_API_BASE_URL is required" }
  if (-not $pathValue) { throw "API path is required" }
  if (-not $pathValue.StartsWith('/')) { $pathValue = "/$pathValue" }
  if ($base -match '/v1$' -and $pathValue -match '^/v1/') {
    $pathValue = $pathValue -replace '^/v1', ''
  }
  return "$base$pathValue"
}

function Get-ByPath {
  param($Object, [string]$Path)
  $current = $Object
  foreach ($part in $Path.Split('.')) {
    if ($null -eq $current) { return $null }
    if ($current -is [System.Collections.IDictionary]) {
      if (-not $current.Contains($part)) { return $null }
      $current = $current[$part]
    } else {
      $prop = $current.PSObject.Properties[$part]
      if (-not $prop) { return $null }
      $current = $prop.Value
    }
  }
  return $current
}

function First-PathValue {
  param($Object, [string[]]$Paths)
  foreach ($path in $Paths) {
    $value = Get-ByPath -Object $Object -Path $path
    if ($null -ne $value -and "${value}".Trim()) {
      return [pscustomobject]@{ Path = $path; Value = $value }
    }
  }
  return $null
}

function Invoke-MoyinRequest {
  param(
    [string]$Method,
    [string]$FullUrl,
    [hashtable]$Headers,
    $BodyObject = $null
  )

  Write-Host "`n==============================" -ForegroundColor Cyan
  Write-Host "METHOD: $Method" -ForegroundColor Yellow
  Write-Host "FULL_URL: $FullUrl" -ForegroundColor Yellow

  $bodyJson = $null
  if ($null -ne $BodyObject) {
    $bodyJson = $BodyObject | ConvertTo-Json -Depth 30 -Compress
    Write-Host "REQUEST BODY:" -ForegroundColor DarkCyan
    Write-Host $bodyJson
  }

  try {
    $params = @{
      Uri = $FullUrl
      Method = $Method
      Headers = $Headers
      TimeoutSec = 120
      UseBasicParsing = $true
      ErrorAction = 'Stop'
    }
    if ($null -ne $bodyJson) { $params.Body = $bodyJson }

    $response = Invoke-WebRequest @params
    Write-Host "STATUS: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "RESPONSE BODY:" -ForegroundColor Green
    Write-Host $response.Content

    $parsed = $null
    try { $parsed = $response.Content | ConvertFrom-Json } catch {}
    return [pscustomobject]@{ Ok = $true; StatusCode = $response.StatusCode; BodyText = $response.Content; Json = $parsed }
  } catch {
    Write-Host "FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red

    $statusCode = $null
    $errorBody = ""
    if ($_.Exception.Response) {
      $statusCode = $_.Exception.Response.StatusCode.value__
      Write-Host "HTTP STATUS:" -ForegroundColor Yellow
      Write-Host $statusCode
      Write-Host $_.Exception.Response.StatusDescription
      try {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "ERROR BODY:" -ForegroundColor Yellow
        Write-Host $errorBody
      } catch {
        Write-Host "Could not read error body."
      }
    }

    if ($statusCode -eq 404 -or $errorBody -match 'Cannot POST|Cannot GET') {
      Write-Host "当前 path 错误，不要写入 n8n workflow。" -ForegroundColor Red
    }

    $parsed = $null
    try { $parsed = $errorBody | ConvertFrom-Json } catch {}
    return [pscustomobject]@{ Ok = $false; StatusCode = $statusCode; BodyText = $errorBody; Json = $parsed }
  }
}

$dotenv = Read-DotEnv -Path $EnvPath

$baseUrl = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_API_BASE_URL' -Default 'https://demo.moyinai.com/api/v1'
$apiKey = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_API_KEY'
$model = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_VIDEO_MODEL' -Default 'veo-omni-flash'
$size = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_VIDEO_SIZE' -Default '720x1280'
$pollInterval = [int](Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_POLL_INTERVAL_SECONDS' -Default '8')
$timeoutSeconds = [int](Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_TIMEOUT_SECONDS' -Default '900')
$createPath = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_CREATE_PATH'
$queryPathTemplate = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_QUERY_PATH_TEMPLATE'
$safeTestPathsRaw = Get-EnvValue -DotEnv $dotenv -Name 'MOYIN_SAFE_TEST_PATHS'

Write-Host "Moyin config:" -ForegroundColor Cyan
Write-Host "MOYIN_API_BASE_URL=$baseUrl"
Write-Host "MOYIN_VIDEO_MODEL=$model"
Write-Host "MOYIN_VIDEO_SIZE=$size"
Write-Host "MOYIN_POLL_INTERVAL_SECONDS=$pollInterval"
Write-Host "MOYIN_TIMEOUT_SECONDS=$timeoutSeconds"
Write-Host "MOYIN_API_KEY exists=$([bool]$apiKey)"
Write-Host "MOYIN_CREATE_PATH configured=$([bool]$createPath)"
Write-Host "MOYIN_QUERY_PATH_TEMPLATE configured=$([bool]$queryPathTemplate)"

if (-not $apiKey) {
  throw "MOYIN_API_KEY is missing. Put it in E:/n8n-video-gemini/.env or current PowerShell environment."
}

$headers = @{
  Authorization = "Bearer $apiKey"
  "Content-Type" = "application/json"
}

$safePaths = @()
if ($safeTestPathsRaw) {
  $safePaths = $safeTestPathsRaw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

if ($safePaths.Count -gt 0) {
  Write-Host "`nTesting non-consuming safe endpoints from MOYIN_SAFE_TEST_PATHS..." -ForegroundColor Cyan
  foreach ($path in $safePaths) {
    $url = Join-ApiUrl -BaseUrl $baseUrl -Path $path
    Invoke-MoyinRequest -Method 'GET' -FullUrl $url -Headers $headers | Out-Null
  }
} else {
  Write-Host "`nNo safe non-consuming endpoint confirmed from docs." -ForegroundColor Yellow
  Write-Host "Set MOYIN_SAFE_TEST_PATHS in .env after copying docs, for example: MOYIN_SAFE_TEST_PATHS=/models,/capabilities" -ForegroundColor Yellow
}

if (-not $RunCreateTest) {
  Write-Host "`nRunCreateTest is false. No create-video request was sent, so no cost should be incurred." -ForegroundColor Yellow
  exit 0
}

if (-not $createPath) {
  throw "MOYIN_CREATE_PATH is not configured. Do not guess. Copy the create path from Moyin docs/API Client first."
}

$createUrl = Join-ApiUrl -BaseUrl $baseUrl -Path $createPath
$createBody = @{
  promptImage = $PromptImage
  promptText = $PromptText
  model = $model
  size = $size
  duration = "5"
  ratio = "9:16"
  watermark = $false
}

$createResult = Invoke-MoyinRequest -Method 'POST' -FullUrl $createUrl -Headers $headers -BodyObject $createBody
if (-not $createResult.Ok) { exit 1 }

$taskIdPaths = @(
  'id', 'task_id', 'taskId',
  'data.id', 'data.task_id', 'data.taskId',
  'data.task.id', 'data.task.task_id', 'data.task.taskId',
  'result.id', 'result.task_id', 'result.taskId',
  'response.id', 'response.task_id', 'response.taskId'
)
$taskIdHit = First-PathValue -Object $createResult.Json -Paths $taskIdPaths
if (-not $taskIdHit) {
  Write-Host "Could not find task_id in create response. Candidate paths checked:" -ForegroundColor Red
  $taskIdPaths | ForEach-Object { Write-Host "- $_" }
  exit 1
}

$taskId = [string]$taskIdHit.Value
Write-Host "`nTASK_ID_PATH=$($taskIdHit.Path)" -ForegroundColor Green
Write-Host "TASK_ID=$taskId" -ForegroundColor Green

if (-not $queryPathTemplate) {
  throw "MOYIN_QUERY_PATH_TEMPLATE is not configured. Copy the query path from Moyin docs/API Client first."
}

$statusPaths = @('status','state','data.status','data.state','data.task.status','data.task.state','result.status','result.state','response.status','response.state')
$videoUrlPaths = @('video_url','output_url','url','data.video_url','data.output_url','data.url','data.task.video_url','data.task.output_url','result.video_url','result.output_url','result.url','response.video_url','response.output_url','response.url')
$successStatuses = @('completed','succeeded','success','done')
$failedStatuses = @('failed','error','cancelled','canceled')

$deadline = (Get-Date).AddSeconds($timeoutSeconds)
do {
  $queryPath = $queryPathTemplate.Replace('{task_id}', [Uri]::EscapeDataString($taskId))
  $queryUrl = Join-ApiUrl -BaseUrl $baseUrl -Path $queryPath
  $queryResult = Invoke-MoyinRequest -Method 'GET' -FullUrl $queryUrl -Headers $headers

  $statusHit = First-PathValue -Object $queryResult.Json -Paths $statusPaths
  $videoHit = First-PathValue -Object $queryResult.Json -Paths $videoUrlPaths
  $status = if ($statusHit) { [string]$statusHit.Value } else { '' }

  Write-Host "STATUS_PATH=$($statusHit.Path) STATUS=$status" -ForegroundColor Cyan
  if ($videoHit) {
    Write-Host "VIDEO_URL_PATH=$($videoHit.Path)" -ForegroundColor Green
    Write-Host "VIDEO_URL=$($videoHit.Value)" -ForegroundColor Green
    exit 0
  }

  if ($failedStatuses -contains $status.ToLowerInvariant()) {
    Write-Host "Task failed with status=$status" -ForegroundColor Red
    exit 1
  }

  if ($successStatuses -contains $status.ToLowerInvariant()) {
    Write-Host "Task reached success status but no video URL was found." -ForegroundColor Yellow
    exit 0
  }

  Start-Sleep -Seconds $pollInterval
} while ((Get-Date) -lt $deadline)

Write-Host "Timed out waiting for Moyin task after $timeoutSeconds seconds." -ForegroundColor Red
exit 1
