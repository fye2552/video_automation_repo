@echo off
setlocal
cd /d %~dp0

set N8N_PORT=5678
set SKILL=custom
set CUSTOM_SKILL_PATH=skills/skill_video_moyin.md
set GENERATE_COUNT=1
set DRY_RUN=false
set SUBMIT_DELAY_SECONDS=5

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

if not exist local_products mkdir local_products
if not exist video_jobs\inbox mkdir video_jobs\inbox
if not exist video_output mkdir video_output

set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
set N8N_LOCAL_PRODUCTS_DIR=%cd%\local_products
set N8N_LOCAL_JOBS_DIR=%cd%\video_jobs
set N8N_LOCAL_OUTPUT_DIR=%cd%\video_output
set NODE_FUNCTION_ALLOW_BUILTIN=fs,path,crypto

echo Starting local npm n8n...
start "n8n-video" cmd /k n8n.cmd

echo Waiting for n8n...
timeout /t 10 /nobreak >nul

where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is required but node was not found.
  goto :fail
)
echo Starting worker watcher...
start "moyin-worker-watcher" cmd /k node workers\worker_watcher.js --jobs-dir video_jobs --worker workers\moyin_worker.js --max-parallel 2 --scan-interval-seconds 5 --idle-timeout-seconds 1800

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




