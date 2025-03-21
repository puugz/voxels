:: Builds the hot_reload.exe
set OUT_DIR=.build\hot_reload
set EXE=hot_reload.exe
odin build src\hot_reload -strict-style -vet -debug -out:%EXE% -pdb-name:%OUT_DIR%\hot_reload.pdb
