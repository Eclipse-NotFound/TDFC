@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build\start-test.ps1" -Mode Observe
if errorlevel 1 pause
