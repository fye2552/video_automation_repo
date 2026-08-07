@echo off
setlocal
cd /d %~dp0

taskkill /F /IM node.exe
endlocal
