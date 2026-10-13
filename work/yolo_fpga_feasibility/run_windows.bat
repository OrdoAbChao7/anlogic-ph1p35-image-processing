@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PYTHON_EXE=%SCRIPT_DIR%..\y1_yolo\.venv\Scripts\python.exe"
if not exist "%PYTHON_EXE%" (
  echo Missing venv Python: %PYTHON_EXE%
  exit /b 1
)
"%PYTHON_EXE%" "%SCRIPT_DIR%reproduce.py" %*
exit /b %ERRORLEVEL%
