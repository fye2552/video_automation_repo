@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set N8N_PORT=5678
set SKILL=custom
set CUSTOM_SKILL_PATH=skills/skill_target_apparel_try_on_laugh.md
set SKILL_REPO_PATH=skills/skill_target_apparel_try_on_laugh.md
set SKILL_SOURCE_FILTER=Skill-*-om-Target*.md
set SKILL_SOURCE_NAME=omini-flash-10s-target-novelty-apparel-try-on
set SKILL_LABEL=Target Apparel Try-On Laugh
set GENERATE_COUNT=1
set DRY_RUN=false
set SUBMIT_DELAY_SECONDS=5
set N8N_RUNNERS_TASK_TIMEOUT=2400
set N8N_RUNNERS_HEARTBEAT_INTERVAL=300
set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
set NODE_FUNCTION_ALLOW_BUILTIN=*

if exist run.lock (
  echo run.lock exists. Another batch submission may be running.
  echo If you are sure nothing is running, delete run.lock manually.
  pause
  exit /b 1
)
echo started %date% %time% > run.lock

if not exist .env (
  echo .env not found. Creating from .env.example...
  copy .env.example .env >nul
  echo Please edit .env and fill required keys, then run this file again.
  del run.lock
  pause
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if not "%%A"=="" if not "%%A:~0,1"=="#" set "%%A=%%B"
)

call "%~dp0configure_video_profile.bat"
if errorlevel 1 (
  if exist run.lock del run.lock
  goto :fail
)

if not defined GITHUB_TOKEN (
  echo GITHUB_TOKEN is required to sync %SKILL_LABEL% to GitHub.
  goto :fail
)

if not exist local_products mkdir local_products
if not exist "%N8N_LOCAL_JOBS_DIR%\inbox" mkdir "%N8N_LOCAL_JOBS_DIR%\inbox"
if not exist "%N8N_LOCAL_OUTPUT_DIR%" mkdir "%N8N_LOCAL_OUTPUT_DIR%"

set WEBHOOK_URL=http://localhost:%N8N_PORT%/
set N8N_LOCAL_PRODUCTS_DIR=E:/n8n-video-gemini/local_products
if not defined N8N_LOCAL_JOBS_DIR set N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs
if not defined N8N_LOCAL_OUTPUT_DIR set N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output

echo Syncing %SKILL_LABEL% to GitHub path %SKILL_REPO_PATH%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $expected=('name: '+$env:SKILL_SOURCE_NAME); $files=@(Get-ChildItem -LiteralPath 'E:\skill' -File -Filter $env:SKILL_SOURCE_FILTER | Where-Object { @(Get-Content -LiteralPath $_.FullName -Encoding UTF8 -TotalCount 12 | Where-Object { $_.Trim() -eq $expected }).Count -eq 1 }); if($files.Count -ne 1){throw ('Expected exactly one Skill source with '+$expected+'; found '+$files.Count)}; $source=$files[0].FullName; $repoPath=$env:SKILL_REPO_PATH; $token=$env:GITHUB_TOKEN; $owner=if($env:GITHUB_OWNER){$env:GITHUB_OWNER}else{'fye2552'}; $repo=if($env:GITHUB_REPO){$env:GITHUB_REPO}else{'video_automation_repo'}; $branch=if($env:GITHUB_BRANCH){$env:GITHUB_BRANCH}else{'main'}; $headers=@{Authorization=('Bearer '+$token);Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}; $encoded=[System.Uri]::EscapeDataString($repoPath).Replace(([char]37+'2F'),'/'); $url=('https://api.github.com/repos/'+$owner+'/'+$repo+'/contents/'+$encoded); $existing=$null; try{$existing=Invoke-RestMethod -Method Get -Uri ($url+'?ref='+[System.Uri]::EscapeDataString($branch)) -Headers $headers}catch{if(-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404){throw}}; $body=@{message=('Sync '+$repoPath);content=[Convert]::ToBase64String([System.IO.File]::ReadAllBytes($source));branch=$branch}; if($existing -and $existing.sha){$body.sha=$existing.sha}; Invoke-RestMethod -Method Put -Uri $url -Headers $headers -ContentType 'application/json' -Body ($body|ConvertTo-Json -Compress) | Out-Null; Write-Host ('Synced source: '+$source)"
if errorlevel 1 goto :fail

echo Starting local npm n8n for %SKILL_LABEL%...
start "n8n-video-target-apparel-laugh" cmd /k n8n start

echo Waiting for n8n at http://localhost:%N8N_PORT% ...
for /l %%I in (1,1,60) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r=Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:%N8N_PORT%/' -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 goto :n8n_ready
  timeout /t 2 /nobreak >nul
)
echo n8n did not become reachable in time.
goto :fail

:n8n_ready
echo n8n is reachable.

echo Starting worker watcher...
where python >nul 2>nul
if errorlevel 1 (
  echo Python is required to run workers\worker_watcher.py but python was not found.
  goto :fail
)
start "moyin-worker-watcher-target-apparel-laugh" cmd /k python workers\worker_watcher.py ^
  --jobs-dir "%N8N_LOCAL_JOBS_DIR%" ^
  --worker E:/n8n-video-gemini/workers/moyin_worker.py ^
  --max-parallel 2 ^
  --scan-interval-seconds 5 ^
  --idle-timeout-seconds 1800

powershell -ExecutionPolicy Bypass -File .\submit_all_products.ps1 -Skill "%SKILL%" -CustomSkillPath "%CUSTOM_SKILL_PATH%" -GenerateCount %GENERATE_COUNT% -DryRun "%DRY_RUN%" -N8nPort %N8N_PORT% -SubmitDelaySeconds %SUBMIT_DELAY_SECONDS%
if errorlevel 1 goto :fail

del run.lock
echo %SKILL_LABEL% batch submission finished.
pause
exit /b 0

:fail
echo %SKILL_LABEL% batch failed.
if exist run.lock del run.lock
pause
exit /b 1
