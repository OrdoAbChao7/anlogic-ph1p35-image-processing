@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

if defined FPGA_PYTHON (
  set "LAB_PYTHON=%FPGA_PYTHON%"
) else (
  set "LAB_PYTHON=python"
)

echo Starting FPGA Algorithm Lab using: %LAB_PYTHON%
echo Web UI Address: http://127.0.0.1:8501
start "" http://127.0.0.1:8501
"%LAB_PYTHON%" -m uvicorn app:app --host 127.0.0.1 --port 8501
pause
