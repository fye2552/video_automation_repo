@echo off
setlocal
cd /d %~dp0

if not exist .env (
  echo .env not found. Creating from .env.example...
  copy .env.example .env >nul
  echo Please edit .env and fill GITHUB_TOKEN, OPENAI_API_KEY, and MOYIN_API_KEY.
  pause
  exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
  if not "%%A"=="" if not "%%A:~0,1"=="#" set "%%A=%%B"
)

if not exist local_products mkdir local_products
if not exist video_jobs\inbox mkdir video_jobs\inbox
if not exist video_output mkdir video_output

set N8N_PORT=5678
set WEBHOOK_URL=http://localhost:5678/
set N8N_BLOCK_ENV_ACCESS_IN_NODE=false
set N8N_LOCAL_PRODUCTS_DIR=E:/n8n-video-gemini/local_products
set N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs
set N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output
set NODE_FUNCTION_ALLOW_BUILTIN=*

 echo Starting local npm n8n on http://localhost:%N8N_PORT% ...
start "n8n-video" cmd /k n8n start

timeout /t 8 /nobreak >nul
start http://localhost:%N8N_PORT%

echo.
echo n8n started in a separate window.
echo video_jobs inbox: %N8N_LOCAL_JOBS_DIR%/inbox
echo video_output: %N8N_LOCAL_OUTPUT_DIR%
endlocal