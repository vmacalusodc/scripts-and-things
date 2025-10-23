@echo off
setlocal
set FILENAME=%~n0
set SCRIPTDIR=%~dp0
set ADMIN=0
if /I "%FILENAME:~0,5%"=="admin" set ADMIN=1

echo Running "%SCRIPTDIR%ScriptsDir\RunScript.ps1" with %FILENAME% (Admin=%ADMIN%)
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%SCRIPTDIR%ScriptsDir\RunScript.ps1" -Script "%FILENAME%" -Admin %ADMIN%
