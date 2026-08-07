@echo off
setlocal
cd /d "%~dp0"
set "VIDEO_PROFILE=normal"
call "start_and_run_all_skill_g_first_person_function.bat"
exit /b %errorlevel%
