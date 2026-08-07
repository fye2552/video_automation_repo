@echo off
setlocal
cd /d "%~dp0"
set "VIDEO_PROFILE=no_watermark"
call "start_and_run_all_skill_shelf_single_sample.bat"
exit /b %errorlevel%
