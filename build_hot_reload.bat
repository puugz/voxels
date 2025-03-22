@echo off

set GAME_RUNNING=false

:: OUT_DIR is for everything except the exe. The exe needs to stay in root
:: folder so it sees the res folder, without having to copy it.
set OUT_DIR=.build\hot_reload
set GAME_PDBS_DIR=%OUT_DIR%\pdbs

set EXE=hot_reload.exe

:: Check if game is running
FOR /F %%x IN ('tasklist /NH /FI "IMAGENAME eq %EXE%"') DO IF %%x == %EXE% set GAME_RUNNING=true

if not exist %OUT_DIR% mkdir %OUT_DIR%

:: If game isn't running then:
:: - delete all game_XXX.dll files
:: - delete all PDBs in pdbs subdir
:: - optionally create the pdbs subdir
:: - write 0 into pdbs\pdb_number so game.dll PDBs start counting from zero
::
:: This makes sure we start over "fresh" at PDB number 0 when starting up the
:: game and it also makes sure we don't have so many PDBs laying around.
if %GAME_RUNNING% == false (
  del /q /s %OUT_DIR% >nul 2>nul
  if not exist "%GAME_PDBS_DIR%" mkdir %GAME_PDBS_DIR%
  echo 0 > %GAME_PDBS_DIR%\pdb_number
)

:: Load PDB number from file, increment and store back. For as long as the game
:: is running the pdb_number file won't be reset to 0, so we'll get a PDB of a
:: unique name on each hot reload.
set /p PDB_NUMBER=<%GAME_PDBS_DIR%\pdb_number
set /a PDB_NUMBER=%PDB_NUMBER%+1
echo %PDB_NUMBER% > %GAME_PDBS_DIR%\pdb_number

:: Build game dll, use pdbs\game_%PDB_NUMBER%.pdb as PDB name so each dll gets
:: its own PDB. This PDB stuff is done in order to make debugging work.
:: Debuggers tend to lock PDBs or just misbehave if you reuse the same PDB while
:: the debugger is attached. So each time we compile `game.dll` we give the
:: PDB a unique PDB.
:: 
:: Note that we could not just rename the PDB after creation; the DLL contains a
:: reference to where the PDB is.
::
:: Also note that we always write game.dll to the same file. hot_reload.exe
:: monitors this file and does the hot reload when it changes.
echo Building game.dll
@REM odin build src -strict-style -vet -debug -build-mode:dll -out:%OUT_DIR%/game.dll -pdb-name:%GAME_PDBS_DIR%\game_%PDB_NUMBER%.pdb > nul
odin build src -debug -build-mode:dll -out:%OUT_DIR%/game.dll -pdb-name:%GAME_PDBS_DIR%\game_%PDB_NUMBER%.pdb
IF %ERRORLEVEL% NEQ 0 exit /b 1

:: If game.exe already running: Then only compile game.dll and exit cleanly
if %GAME_RUNNING% == true (
  echo Hot reloading... && exit /b 0
)

if "%~1"=="run" (
  echo Running %EXE%...
  start %EXE%
)
