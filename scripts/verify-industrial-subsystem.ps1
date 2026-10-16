# ==============================================================================
# Script: verify-industrial-subsystem.ps1
# Description: One-click verification for PH1P35 Industrial Inspection Subsystem
# Verifies:
#   1. Algorithm Lab Python Reference vs Hardware-Equivalent Model (5 Benchmark Cases)
#   2. Baseline color_detect_96.v Icarus Verilog Simulation
#   3. Subsystem (color_detect_96_v2 + morph_open_96 + defect_classifier + bbox_draw_overlay) Simulation
# ==============================================================================

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$WorkspaceRoot = Resolve-Path "$ScriptDir\.."

Set-Location $WorkspaceRoot
$VerificationOutput = Join-Path $WorkspaceRoot "work\tests\verification_outputs"
New-Item -ItemType Directory -Force -Path $VerificationOutput | Out-Null
$python = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
if (-not $python) {
    $pythonRoot = Join-Path $env:LOCALAPPDATA "Programs\Python"
    if (Test-Path $pythonRoot) {
        $python = Get-ChildItem -LiteralPath $pythonRoot -Filter python.exe -File -Recurse |
            Sort-Object FullName -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $python) {
    Write-Host "[ERROR] Python executable not found. Install Python or expose python.exe in PATH." -ForegroundColor Red
    exit 1
}

function Invoke-CapturedTool {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $stdoutPath = Join-Path $VerificationOutput "$Name.stdout.log"
    $stderrPath = Join-Path $VerificationOutput "$Name.stderr.log"
    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
        -WorkingDirectory $WorkspaceRoot -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath | ForEach-Object { Write-Host $_ } }
    if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath | ForEach-Object { Write-Host $_ } }
    return [int]$process.ExitCode
}
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "PH1P35 INDUSTRIAL INSPECTION SUBSYSTEM VERIFICATION SUITE" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot" -ForegroundColor Gray
Write-Host "================================================================================" -ForegroundColor Cyan

# Step 1: Run Python Algorithm Lab Test Suite
Write-Host "`n[1/3] Running Python Algorithm Lab Benchmark Tests..." -ForegroundColor Yellow
$pythonExit = Invoke-CapturedTool -FilePath $python `
    -Arguments @("work/algorithm_lab/test_industrial_inspection.py") -Name "algorithm_lab"
if ($pythonExit -ne 0) {
    Write-Host "[FAIL] Python Algorithm Lab benchmark tests failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Python Benchmark Suite PASSED." -ForegroundColor Green

# Step 2: Run Baseline color_detect_96.v Simulation
Write-Host "`n[2/3] Running Baseline color_detect_96.v Icarus Verilog Simulation..." -ForegroundColor Yellow
$iverilog = Join-Path $WorkspaceRoot ".tools\iverilog\bin\iverilog.exe"
$vvp = Join-Path $WorkspaceRoot ".tools\iverilog\bin\vvp.exe"

if (-not (Test-Path $iverilog)) {
    $sharedToolRoot = $env:FPGA_IVERILOG_ROOT
    if (-not $sharedToolRoot) { $sharedToolRoot = "E:\Projects\FPGA\.tools" }
    $iverilog = Join-Path $sharedToolRoot "iverilog\bin\iverilog.exe"
    $vvp = Join-Path $sharedToolRoot "iverilog\bin\vvp.exe"
}

if (-not (Test-Path $iverilog)) {
    Write-Host "[WARN] Icarus Verilog not found in workspace/shared tools. Checking PATH..." -ForegroundColor Yellow
    $iverilog = (Get-Command iverilog.exe -ErrorAction SilentlyContinue).Source
    $vvp = (Get-Command vvp.exe -ErrorAction SilentlyContinue).Source
}

if (-not $iverilog -or -not $vvp) {
    Write-Host "[ERROR] iverilog or vvp simulator not found!" -ForegroundColor Red
    exit 1
}

$iverilogRoot = Split-Path (Split-Path $iverilog -Parent) -Parent
$ivlInternal = Join-Path $iverilogRoot "lib\ivl"
if (Test-Path $ivlInternal) {
    $env:PATH = "$ivlInternal;$env:PATH"
}
if ($env:PATHEXT -notmatch "(?i)\.EXE") {
    $env:PATHEXT = ".COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC"
}

$BaselineVvp = Join-Path $VerificationOutput "tb_color_baseline.vvp"
$baselineCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "baseline_compile" -Arguments @(
    "-o", $BaselineVvp, "-s", "tb_color_detect_96",
    "fallback/tb_color_detect_96.v", "fallback/rtl/color_detect_96.v"
)
if ($baselineCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_color_detect_96.v failed!" -ForegroundColor Red
    exit 1
}

$baselineRunExit = Invoke-CapturedTool -FilePath $vvp -Name "baseline_run" -Arguments @($BaselineVvp)
if ($baselineRunExit -ne 0) {
    Write-Host "[FAIL] Simulation of tb_color_detect_96.v failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Baseline color_detect_96.v Simulation PASSED." -ForegroundColor Green

# Step 3: Run Industrial Subsystem Simulation
Write-Host "`n[3/3] Running Integrated Subsystem Icarus Verilog Simulation..." -ForegroundColor Yellow
$SubsystemVvp = Join-Path $VerificationOutput "tb_industrial_subsystem.vvp"
$subsystemCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "subsystem_compile" -Arguments @(
    "-g2012", "-DMORPH_SIMULATION", "-o", $SubsystemVvp,
    "fallback/tb_industrial_subsystem.v", "fallback/rtl/morph_open_96.v",
    "fallback/rtl/color_detect_96_v2.v", "fallback/rtl/defect_classifier.v",
    "fallback/rtl/bbox_draw_overlay.v"
)
if ($subsystemCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_industrial_subsystem.v failed!" -ForegroundColor Red
    exit 1
}

$subsystemRunExit = Invoke-CapturedTool -FilePath $vvp -Name "subsystem_run" -Arguments @($SubsystemVvp)
if ($subsystemRunExit -ne 0) {
    Write-Host "[FAIL] Simulation of tb_industrial_subsystem.v failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Subsystem Integrated Simulation PASSED." -ForegroundColor Green

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ">>> ALL INDUSTRIAL INSPECTION TESTS COMPLETED SUCCESSFULLY (100% PASS) <<<" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
exit 0
