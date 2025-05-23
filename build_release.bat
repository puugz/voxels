:: This script creates an optimized release build.

@echo off

set OUT_DIR=.build\release

if not exist %OUT_DIR% mkdir %OUT_DIR%

@REM odin build src\release -out:%OUT_DIR%\release.exe -strict-style -vet -no-bounds-check -o:speed -subsystem:windows
odin build src\release -out:%OUT_DIR%\release.exe -no-bounds-check -o:speed -subsystem:windows
IF %ERRORLEVEL% NEQ 0 exit /b 1

xcopy /y /e /i res %OUT_DIR%\res > nul
IF %ERRORLEVEL% NEQ 0 exit /b 1

echo Release build created in %OUT_DIR%
