@echo on
REM set scriptname
set arg1=%1
REM set
set arg2=%2


echo Running "%SCRIPTDIR%ScriptsDir\RunScript.ps1" with %arg1% (Admin=%arg2%)
powershell.exe Set-ExecutionPolicy Unrestricted
powershell.exe  -File "%SCRIPTDIR%ScriptsDir\RunScript.ps1" -Script "%arg1%" -Admin %arg2%