@echo off
setlocal
cd /d %~dp0

set N8N_PORT=5678
set SKILL=skill_c
set CUSTOM_SKILL_PATH=
set GENERATE_COUNT=1
set DRY_RUN=false
set SUBMIT_DELAY_SECONDS=5
set N8N_RUNNERS_TASK_TIMEOUT=2400

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

if not exist local_products mkdir local_products
if not exist "%N8N_LOCAL_JOBS_DIR%\inbox" mkdir "%N8N_LOCAL_JOBS_DIR%\inbox"
if not exist "%N8N_LOCAL_OUTPUT_DIR%" mkdir "%N8N_LOCAL_OUTPUT_DIR%"

set WEBHOOK_URL=http://localhost:5678/
set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
set N8N_LOCAL_PRODUCTS_DIR=E:/n8n-video-gemini/local_products
if not defined N8N_LOCAL_JOBS_DIR set N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs
if not defined N8N_LOCAL_OUTPUT_DIR set N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output
set NODE_FUNCTION_ALLOW_BUILTIN=*

echo Starting local npm n8n...
start "n8n-video" cmd /k n8n start

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
start "moyin-worker-watcher" cmd /k python workers\worker_watcher.py ^
  --jobs-dir "%N8N_LOCAL_JOBS_DIR%" ^
  --worker E:/n8n-video-gemini/workers/moyin_worker.py ^
  --max-parallel 2 ^
  --scan-interval-seconds 5 ^
  --idle-timeout-seconds 1800

powershell -ExecutionPolicy Bypass -File .\submit_all_products.ps1 -Skill "%SKILL%" -CustomSkillPath "%CUSTOM_SKILL_PATH%" -GenerateCount %GENERATE_COUNT% -DryRun "%DRY_RUN%" -N8nPort %N8N_PORT% -SubmitDelaySeconds %SUBMIT_DELAY_SECONDS%
if errorlevel 1 goto :fail

del run.lock
echo Batch submission finished.
pause
exit /b 0

:fail
echo Batch failed. If no submission is running, delete run.lock manually.
pause
exit /b 1
