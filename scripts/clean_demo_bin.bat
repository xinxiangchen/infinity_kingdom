@echo off
setlocal
del /q demo\bin\*.dll 2>nul
del /q demo\bin\*.exp 2>nul
del /q demo\bin\*.lib 2>nul
del /q demo\bin\*.pdb 2>nul
endlocal
