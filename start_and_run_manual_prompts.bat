@echo off
setlocal
cd /d %~dp0

set N8N_PORT=5678
set DRY_RUN=false
set N8N_RUNNERS_TASK_TIMEOUT=2400
set N8N_RUNNERS_HEARTBEAT_INTERVAL=300
set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
set NODE_FUNCTION_ALLOW_BUILTIN=*
set N8N_LOCAL_PRODUCTS_DIR=E:/n8n-video-gemini/local_products
set N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs
set N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output
set WEBHOOK_URL=http://localhost:5678/

if exist manual_prompt_run.lock (
  echo Manual prompt submission is already running.
  echo If you are sure no submission is running, delete manual_prompt_run.lock and run again.
  pause
  exit /b 1
)
echo started %date% %time% > manual_prompt_run.lock

if not exist .env (
  echo .env was not found. Copy .env.example to .env and configure the required keys.
  del manual_prompt_run.lock
  pause
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if not "%%A"=="" if not "%%A:~0,1"=="#" set "%%A=%%B"
)

call "%~dp0configure_video_profile.bat"
if errorlevel 1 goto :fail

if not exist "manual_prompts\pending" mkdir "manual_prompts\pending"
if not exist "manual_prompts\submitted" mkdir "manual_prompts\submitted"
if not exist "%N8N_LOCAL_JOBS_DIR%\inbox" mkdir "%N8N_LOCAL_JOBS_DIR%\inbox"
if not exist "%N8N_LOCAL_OUTPUT_DIR%" mkdir "%N8N_LOCAL_OUTPUT_DIR%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%N8N_PORT%/' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
if errorlevel 1 (
  echo Starting local n8n...
  start "n8n-manual-prompt" cmd /k n8n start
)

echo Waiting for n8n at http://127.0.0.1:%N8N_PORT% ...
for /l %%I in (1,1,60) do (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:%N8N_PORT%/' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 goto :n8n_ready
  timeout /t 2 /nobreak >nul
)
echo n8n did not become reachable in time.
goto :fail

:n8n_ready
where python >nul 2>nul
if errorlevel 1 (
  echo Python was not found. Install Python 3.11+ and add it to PATH.
  goto :fail
)

echo Starting worker watcher...
start "manual-prompt-worker-watcher" cmd /k python workers\worker_watcher.py ^
  --jobs-dir "%N8N_LOCAL_JOBS_DIR%" ^
  --worker E:/n8n-video-gemini/workers/moyin_worker.py ^
  --max-parallel 2 ^
  --scan-interval-seconds 5 ^
  --idle-timeout-seconds 1800

if /I "%DRY_RUN%"=="true" (
  powershell -NoProfile -ExecutionPolicy Bypass -File .\submit_manual_prompts.ps1 -N8nPort %N8N_PORT% -DryRun
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File .\submit_manual_prompts.ps1 -N8nPort %N8N_PORT%
)
if errorlevel 1 goto :fail

del manual_prompt_run.lock
echo Manual prompt batch submission finished.
pause
exit /b 0

:fail
echo Manual prompt batch failed. Pending prompt files were not moved.
if exist manual_prompt_run.lock del manual_prompt_run.lock
pause
exit /b 1
