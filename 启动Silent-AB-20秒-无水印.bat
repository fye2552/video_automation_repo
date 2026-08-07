@echo off
setlocal
cd /d "%~dp0"
set "VIDEO_PROFILE=no_watermark"
call "start_and_run_all_silent_ab20.bat"
exit /b %errorlevel%
