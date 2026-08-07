@echo off
setlocal
cd /d "%~dp0"
set "VIDEO_PROFILE=normal"
call "start_and_run_manual_prompts.bat"
exit /b %errorlevel%
