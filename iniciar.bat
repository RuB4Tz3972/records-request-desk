@echo off
title Records Request Desk (modo consola)
rem Para el dia a dia usa el icono del escritorio. Esta ventana sirve para ver mensajes si algo falla.
cd /d "%~dp0"

set "UV_PROJECT_ENVIRONMENT=%LOCALAPPDATA%\RecordsRequestDesk\venv"
set "PYTHONDONTWRITEBYTECODE=1"

where uv >nul 2>nul
if errorlevel 1 (
  echo No se encontro "uv" en esta PC. Instalalo una sola vez siguiendo README.md
  pause
  exit /b 1
)

uv run python server.py
pause
