@echo off
rem TDFC mod build script (ASCII only - cmd parses by system codepage)
rem Toolchain (probed 2026-08-27, see knowledge/facts/build-environment.md):
rem   mxmlc 4.16.1 + AIR SDK 51: D:\RemainsMod\mods\Sandevistan\build\tools\
rem   Java: Adobe Animate 2024 bundled JRE (system has no standalone JDK)
rem Output: build\out\TDFCMod.swf (candidate only)

setlocal
set "JAVA_HOME=D:\Program Files\Adobe Animate 2024\jre"
set "PATH=%JAVA_HOME%\bin;%PATH%"
set "FLEXBIN=D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\bin"
cd /d "%~dp0.."
if not exist build\out mkdir build\out
"%FLEXBIN%\mxmlc.bat" -load-config build\tdfc-config.xml -output build\out\TDFCMod.swf src\TDFCMod.as
if errorlevel 1 exit /b 1
echo [OK] Candidate built in build\out\TDFCMod.swf. Production release unchanged.
