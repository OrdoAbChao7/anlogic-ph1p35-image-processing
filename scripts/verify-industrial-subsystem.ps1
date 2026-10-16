# ==============================================================================
# Script: verify-industrial-subsystem.ps1
# Description: One-click verification for PH1P35 Industrial Inspection Subsystem
# Verifies:
#   1. Algorithm Lab Python Reference vs Hardware-Equivalent Model (5 Benchmark Cases)
#   2. Baseline color_detect_96.v Icarus Verilog Simulation
#   3. Subsystem (color_detect_96_v2 + defect_classifier + bbox_draw_overlay) Simulation
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WorkspaceRoot = Resolve-Path "$ScriptDir\.."

Set-Location $WorkspaceRoot
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "PH1P35 INDUSTRIAL INSPECTION SUBSYSTEM VERIFICATION SUITE" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot" -ForegroundColor Gray
Write-Host "================================================================================" -ForegroundColor Cyan

# Step 1: Run Python Algorithm Lab Test Suite
Write-Host "`n[1/3] Running Python Algorithm Lab Benchmark Tests..." -ForegroundColor Yellow
python work/algorithm_lab/test_industrial_inspection.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Python Algorithm Lab benchmark tests failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Python Benchmark Suite PASSED." -ForegroundColor Green

# Step 2: Run Baseline color_detect_96.v Simulation
Write-Host "`n[2/3] Running Baseline color_detect_96.v Icarus Verilog Simulation..." -ForegroundColor Yellow
$iverilog = "C:\iverilog\bin\iverilog.exe"
$vvp = "C:\iverilog\bin\vvp.exe"

if (-not (Test-Path $iverilog)) {
    Write-Host "[WARN] Icarus Verilog not found at C:\iverilog\bin\iverilog.exe. Checking PATH..." -ForegroundColor Yellow
    $iverilog = (Get-Command iverilog.exe -ErrorAction SilentlyContinue).Source
    $vvp = (Get-Command vvp.exe -ErrorAction SilentlyContinue).Source
}

if (-not $iverilog -or -not $vvp) {
    Write-Host "[ERROR] iverilog or vvp simulator not found!" -ForegroundColor Red
    exit 1
}

& $iverilog -o fallback/tb_color.vvp -s tb_color_detect_96 fallback/tb_color_detect_96.v fallback/rtl/color_detect_96.v
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Compilation of tb_color_detect_96.v failed!" -ForegroundColor Red
    exit 1
}

& $vvp fallback/tb_color.vvp
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Simulation of tb_color_detect_96.v failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Baseline color_detect_96.v Simulation PASSED." -ForegroundColor Green

# Step 3: Run Industrial Subsystem Simulation
Write-Host "`n[3/3] Running Integrated Subsystem Icarus Verilog Simulation..." -ForegroundColor Yellow
& $iverilog -g2012 -o fallback/tb_industrial_subsystem.vvp fallback/tb_industrial_subsystem.v fallback/rtl/color_detect_96_v2.v fallback/rtl/defect_classifier.v fallback/rtl/bbox_draw_overlay.v
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Compilation of tb_industrial_subsystem.v failed!" -ForegroundColor Red
    exit 1
}

& $vvp fallback/tb_industrial_subsystem.vvp
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] Simulation of tb_industrial_subsystem.v failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Subsystem Integrated Simulation PASSED." -ForegroundColor Green

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ">>> ALL INDUSTRIAL INSPECTION TESTS COMPLETED SUCCESSFULLY (100% PASS) <<<" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
exit 0
