@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set "LAB_PYTHON=%~dp0..\y1_yolo\.venv\Scripts\python.exe"
if not exist "%LAB_PYTHON%" (
  set "LAB_PYTHON=E:\Projects\FPGA\work\y1_yolo\.venv\Scripts\python.exe"
)
if not exist "%LAB_PYTHON%" (
  set "LAB_PYTHON=python"
)

echo Starting FPGA Algorithm Lab using: %LAB_PYTHON%
echo Web UI Address: http://127.0.0.1:8501
start "" http://127.0.0.1:8501
"%LAB_PYTHON%" -m uvicorn app:app --host 127.0.0.1 --port 8501
pause
