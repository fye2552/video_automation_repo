@echo off
setlocal
cd /d "%~dp0"
set "VIDEO_PROFILE=normal"
call "start_and_run_all_skill_shelf_single_sample.bat"
exit /b %errorlevel%
