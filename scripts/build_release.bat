@echo off
setlocal
cd /d %~dp0..
scons platform=windows target=template_release
endlocal
