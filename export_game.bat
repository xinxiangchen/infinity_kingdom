@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\export_build.ps1" %*

if errorlevel 1 (
  echo.
  echo Export failed. Install Godot export templates if the log asks for them.
  pause
)
