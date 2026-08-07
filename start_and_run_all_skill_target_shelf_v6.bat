@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set N8N_PORT=5678
set SKILL=custom
set CUSTOM_SKILL_PATH=skills/skill_target_shelf_intro_v6.md
set SKILL_SOURCE_FILTER=Skill-*-om-Target*(6).md
set SKILL_REPO_PATH=skills/skill_target_shelf_intro_v6.md
set SKILL_LABEL=Target Shelf Intro V6
set GENERATE_COUNT=1
set DRY_RUN=false
set SUBMIT_DELAY_SECONDS=5
set N8N_RUNNERS_TASK_TIMEOUT=2400
set N8N_RUNNERS_HEARTBEAT_INTERVAL=300
set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
set NODE_FUNCTION_ALLOW_BUILTIN=*

if not exist ".env" (
  echo ERROR: Missing %CD%\.env
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if not "%%A"=="" if not "%%A:~0,1"=="#" set "%%A=%%B"
)

call "%~dp0configure_video_profile.bat"
if errorlevel 1 exit /b 1

set WEBHOOK_URL=http://localhost:%N8N_PORT%/
set N8N_LOCAL_PRODUCTS_DIR=E:/n8n-video-gemini/local_products
if not defined N8N_LOCAL_JOBS_DIR set N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs
if not defined N8N_LOCAL_OUTPUT_DIR set N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output

if not exist local_products mkdir local_products
if not exist "%N8N_LOCAL_JOBS_DIR%\inbox" mkdir "%N8N_LOCAL_JOBS_DIR%\inbox"
if not exist "%N8N_LOCAL_OUTPUT_DIR%" mkdir "%N8N_LOCAL_OUTPUT_DIR%"

if "%GITHUB_TOKEN%"=="" (
  echo ERROR: GITHUB_TOKEN is required in .env
  exit /b 1
)

echo Syncing %SKILL_LABEL% to GitHub path %SKILL_REPO_PATH%...
set SKILL_REPO_PATH=%SKILL_REPO_PATH%
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $files=@(Get-ChildItem -LiteralPath 'E:\skill' -File -Filter $env:SKILL_SOURCE_FILTER); if($files.Count -ne 1){ throw ('Expected exactly one Skill source for filter ' + $env:SKILL_SOURCE_FILTER + ', found ' + $files.Count) }; $source=$files[0].FullName; $repoPath=$env:SKILL_REPO_PATH; $token=$env:GITHUB_TOKEN; $headers=@{Authorization=('Bearer '+$token);Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}; $content=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($source,[Text.Encoding]::UTF8))); $uri='https://api.github.com/repos/fye2552/video_automation_repo/contents/'+$repoPath; try{$existing=Invoke-RestMethod -Method Get -Uri ($uri+'?ref=main') -Headers $headers; $sha=$existing.sha}catch{if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -ne 404){throw};$sha=$null}; $body=@{message=('Sync '+$env:SKILL_LABEL);content=$content;branch='main'};if($sha){$body.sha=$sha}; Invoke-RestMethod -Method Put -Uri $uri -Headers $headers -ContentType 'application/json' -Body ($body|ConvertTo-Json -Compress) | Out-Null; Write-Host ('Synced source: '+$source)"
if errorlevel 1 (
  echo ERROR: Skill sync failed.
  exit /b 1
)
echo %SKILL_LABEL% synced.

echo Starting local npm n8n for %SKILL_LABEL%...
start "n8n-video-target-shelf-v6" /min cmd /c "n8n start"

echo Waiting for n8n at http://localhost:%N8N_PORT% ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$deadline=(Get-Date).AddSeconds(90); do { try { Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%N8N_PORT%/' -TimeoutSec 3 | Out-Null; exit 0 } catch { Start-Sleep -Seconds 2 } } while((Get-Date) -lt $deadline); exit 1"
if errorlevel 1 (
  echo ERROR: n8n did not become reachable.
  exit /b 1
)
echo n8n is reachable.

echo Starting worker watcher...
start "moyin-worker-watcher-target-shelf-v6" /min cmd /k "python workers\worker_watcher.py --jobs-dir %N8N_LOCAL_JOBS_DIR% --worker E:/n8n-video-gemini/workers/moyin_worker.py --max-parallel 2 --scan-interval-seconds 5 --idle-timeout-seconds 1800"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\submit_all_products.ps1" -Skill "%SKILL%" -CustomSkillPath "%CUSTOM_SKILL_PATH%" -GenerateCount %GENERATE_COUNT% -DryRun:%DRY_RUN% -SubmitDelaySeconds %SUBMIT_DELAY_SECONDS%
echo %SKILL_LABEL% batch submission finished.
pause
