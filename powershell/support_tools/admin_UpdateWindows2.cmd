@echo on
setlocal
set FILENAME=%~n0
set SCRIPTDIR=%~dp0
set ADMIN=0
if /I "%FILENAME:~0,5%"=="admin" set ADMIN=1

echo Running "%SCRIPTDIR%RunCmd.cmd" with %FILENAME% (Admin=%ADMIN%)
powershell.exe -ExecutionPolicy Unrestricted -NoProfile -File "%SCRIPTDIR%ScriptsDir\RunScript.ps1" -Script "%FILENAME%" -Admin %ADMIN%