@echo off
setlocal
cd /d "%~dp0"
set "VIDEO_PROFILE=normal"
call "start_and_run_all_skill_target_apparel_try_on_laugh.bat"
exit /b %errorlevel%
