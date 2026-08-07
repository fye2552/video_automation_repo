@echo off

if not defined N8N_LOCAL_JOBS_DIR set "N8N_LOCAL_JOBS_DIR=E:/n8n-video-gemini/video_jobs"
if not defined N8N_LOCAL_OUTPUT_DIR set "N8N_LOCAL_OUTPUT_DIR=E:/n8n-video-gemini/video_output"

if /I not "%VIDEO_PROFILE%"=="no_watermark" (
  if not defined WATERMARK set "WATERMARK=true"
  exit /b 0
)

if not defined MOYIN_API_KEY_NO_WATERMARK (
  echo ERROR: MOYIN_API_KEY_NO_WATERMARK is required in .env.
  exit /b 1
)
if not defined MOYIN_VIDEO_MODEL_NO_WATERMARK (
  echo ERROR: MOYIN_VIDEO_MODEL_NO_WATERMARK is required in .env.
  exit /b 1
)
if not defined N8N_LOCAL_JOBS_DIR_NO_WATERMARK (
  echo ERROR: N8N_LOCAL_JOBS_DIR_NO_WATERMARK is required in .env.
  exit /b 1
)
if not defined N8N_LOCAL_OUTPUT_DIR_NO_WATERMARK (
  echo ERROR: N8N_LOCAL_OUTPUT_DIR_NO_WATERMARK is required in .env.
  exit /b 1
)

set "MOYIN_API_KEY=%MOYIN_API_KEY_NO_WATERMARK%"
set "MOYIN_VIDEO_MODEL=%MOYIN_VIDEO_MODEL_NO_WATERMARK%"
set "WATERMARK=false"
set "N8N_LOCAL_JOBS_DIR=%N8N_LOCAL_JOBS_DIR_NO_WATERMARK%"
set "N8N_LOCAL_OUTPUT_DIR=%N8N_LOCAL_OUTPUT_DIR_NO_WATERMARK%"
exit /b 0
