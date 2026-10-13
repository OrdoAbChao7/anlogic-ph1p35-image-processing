@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "LAB_PYTHON=%~dp0..\y1_yolo\.venv\Scripts\python.exe"
if not exist "%LAB_PYTHON%" (
  echo Missing Python environment: work/y1_yolo/.venv
  pause
  exit /b 1
)
"%LAB_PYTHON%" -c "import fastapi, uvicorn, cv2, torch, ultralytics"
if errorlevel 1 (
  echo Algorithm Lab dependencies are missing from the project environment.
  pause
  exit /b 1
)
echo Algorithm Lab: http://127.0.0.1:8501
start "" http://127.0.0.1:8501
"%LAB_PYTHON%" -m uvicorn app:app --host 127.0.0.1 --port 8501
pause
