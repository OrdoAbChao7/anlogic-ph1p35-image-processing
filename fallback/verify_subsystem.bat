@echo off
setlocal
echo ================================================================================
echo Running PH1P35 Industrial Inspection Verification Suite...
echo ================================================================================
cd /d "%~dp0\.."
powershell -ExecutionPolicy Bypass -File "%~dp0\..\scripts\verify-industrial-subsystem.ps1"
if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] Verification failed with exit code %ERRORLEVEL%!
    pause
    exit /b %ERRORLEVEL%
)
echo.
echo [SUCCESS] Verification passed successfully!
endlocal
