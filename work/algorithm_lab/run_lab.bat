@echo off
chcp 65001 >nul
echo ===================================================
echo   FPGA Algorithm Lab (Software-First 预览平台)
echo ===================================================
echo.
echo [1/2] 正在启动本地 FastAPI 算法服务...
cd /d "%~dp0"
start "" http://127.0.0.1:8501
python -m uvicorn app:app --host 127.0.0.1 --port 8501
pause
