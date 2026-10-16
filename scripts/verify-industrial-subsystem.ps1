# ==============================================================================
# Script: verify-industrial-subsystem.ps1
# Description: One-click verification for PH1P35 Industrial Inspection Subsystem
# Verifies:
#   1. Algorithm Lab Python Reference vs Hardware-Equivalent Model (5 Benchmark Cases)
#   2. Frozen Stage D and industrial-contract Python tests
#   3. Baseline color_detect_96.v Icarus Verilog Simulation
#   4. 1280x720 full-foreground area and bounding-box regression
#   5. Strict Q10 Cb/Cr open-interval boundary regression
#   6. Subsystem (color_detect_96_v2 + morph_open_96 + defect_classifier + bbox_draw_overlay) Simulation
#   7. Approved three-mode streaming RTL comparison
#   8. OSD/Logo/status and LED joint RTL simulation
#   9. Debounced frame-boundary mode-controller RTL simulation
#  10. Four-state classifier and LED exclusivity RTL simulation
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
Write-Host "`n[1/10] Running Python Algorithm Lab Benchmark Tests..." -ForegroundColor Yellow
$pythonExit = Invoke-CapturedTool -FilePath $python `
    -Arguments @("work/algorithm_lab/test_industrial_inspection.py") -Name "algorithm_lab"
if ($pythonExit -ne 0) {
    Write-Host "[FAIL] Python Algorithm Lab benchmark tests failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Python Benchmark Suite PASSED." -ForegroundColor Green

# Step 2: Run the frozen hardware-equivalent and contract tests
Write-Host "`n[2/10] Running Frozen Stage D and Industrial Contract Tests..." -ForegroundColor Yellow
$stageDExit = Invoke-CapturedTool -FilePath $python `
    -Arguments @("work/algorithm_lab/test_stage_d.py") -Name "stage_d"
if ($stageDExit -ne 0) {
    Write-Host "[FAIL] Stage D hardware-equivalent tests failed!" -ForegroundColor Red
    exit 1
}
$industrialContractExit = Invoke-CapturedTool -FilePath $python `
    -Arguments @("work/algorithm_lab/test_industrial_contract.py") -Name "industrial_contract"
if ($industrialContractExit -ne 0) {
    Write-Host "[FAIL] Industrial contract tests failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Frozen Stage D and industrial contract tests PASSED." -ForegroundColor Green

# Step 3: Run Baseline color_detect_96.v Simulation
Write-Host "`n[3/10] Running Baseline color_detect_96.v Icarus Verilog Simulation..." -ForegroundColor Yellow
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

# Step 4: Run the real 1280x720 full-foreground regression
Write-Host "`n[4/10] Running 1280x720 Full-Frame Area Regression..." -ForegroundColor Yellow
$FullFrameVvp = Join-Path $VerificationOutput "tb_color_detect_96_v2_full_frame.vvp"
$fullFrameCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "full_frame_compile" -Arguments @(
    "-g2012", "-DMORPH_SIMULATION", "-Wall", "-s", "tb_color_detect_96_v2",
    "-o", $FullFrameVvp, "fallback/tb_color_detect_96_v2.v",
    "fallback/rtl/morph_open_96.v", "fallback/rtl/color_detect_96_v2.v"
)
if ($fullFrameCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_color_detect_96_v2.v failed!" -ForegroundColor Red
    exit 1
}
$fullFrameRunExit = Invoke-CapturedTool -FilePath $vvp -Name "full_frame_run" -Arguments @($FullFrameVvp)
if ($fullFrameRunExit -ne 0) {
    Write-Host "[FAIL] 1280x720 full-frame area regression failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] 1280x720 full-frame area=921600 regression PASSED." -ForegroundColor Green

# Step 5: Run strict Q10 threshold boundary vectors
Write-Host "`n[5/10] Running Strict Q10 Cb/Cr Boundary Regression..." -ForegroundColor Yellow
$ThresholdBoundariesVvp = Join-Path $VerificationOutput "tb_color_detect_96_v2_boundaries.vvp"
$thresholdBoundariesCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "threshold_boundaries_compile" -Arguments @(
    "-g2012", "-DMORPH_SIMULATION", "-Wall", "-s", "tb_color_detect_96_v2_boundaries",
    "-o", $ThresholdBoundariesVvp, "fallback/tb_color_detect_96_v2_boundaries.v",
    "fallback/rtl/morph_open_96.v", "fallback/rtl/color_detect_96_v2.v"
)
if ($thresholdBoundariesCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_color_detect_96_v2_boundaries.v failed!" -ForegroundColor Red
    exit 1
}
$thresholdBoundariesRunExit = Invoke-CapturedTool -FilePath $vvp -Name "threshold_boundaries_run" -Arguments @($ThresholdBoundariesVvp)
if ($thresholdBoundariesRunExit -ne 0) {
    Write-Host "[FAIL] Strict Q10 Cb/Cr boundary regression failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Strict Q10 Cb/Cr open-interval boundary regression PASSED." -ForegroundColor Green

# Step 6: Run Industrial Subsystem Simulation
Write-Host "`n[6/10] Running Integrated Subsystem Icarus Verilog Simulation..." -ForegroundColor Yellow
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

# Step 7: Run the approved Original/Sobel/Cartoon streaming comparison
Write-Host "`n[7/10] Running Approved Three-Mode Streaming RTL Comparison..." -ForegroundColor Yellow
$modeExit = Invoke-CapturedTool -FilePath $python `
    -Arguments @("work/tests/run_cartoon_luma_sim.py") -Name "three_mode"
if ($modeExit -ne 0) {
    Write-Host "[FAIL] Approved three-mode streaming comparison failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Approved Original/Sobel/Cartoon streaming comparison PASSED." -ForegroundColor Green

# Step 8: Run OSD/Logo/status and LED joint simulation
Write-Host "`n[8/10] Running OSD/Logo/LED Joint Simulation..." -ForegroundColor Yellow
$OsdVvp = Join-Path $VerificationOutput "tb_osd_led_joint.vvp"
$osdCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "osd_led_compile" -Arguments @(
    "-g2012", "-Wall", "-s", "tb_osd_led_joint", "-o", $OsdVvp,
    "fallback/tb_osd_led_joint.v", "fallback/rtl/defect_classifier.v",
    "fallback/rtl/anlogic_logo_rom.v", "fallback/rtl/industrial_osd_overlay.v"
)
if ($osdCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_osd_led_joint.v failed!" -ForegroundColor Red
    exit 1
}
$osdRunExit = Invoke-CapturedTool -FilePath $vvp -Name "osd_led_run" -Arguments @($OsdVvp)
if ($osdRunExit -ne 0) {
    Write-Host "[FAIL] OSD/Logo/LED joint simulation failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] OSD/Logo/LED joint simulation PASSED." -ForegroundColor Green

# Step 9: Run mode-controller debounce and frame-boundary simulation
Write-Host "`n[9/10] Running Mode-Controller Debounce/Frame-Boundary Simulation..." -ForegroundColor Yellow
$ModeVvp = Join-Path $VerificationOutput "tb_mode_controller.vvp"
$modeCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "mode_controller_compile" -Arguments @(
    "-g2012", "-Wall", "-s", "tb_mode_controller", "-o", $ModeVvp,
    "fallback/tb_mode_controller.v", "fallback/rtl/mode_controller.v"
)
if ($modeCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_mode_controller.v failed!" -ForegroundColor Red
    exit 1
}
$modeRunExit = Invoke-CapturedTool -FilePath $vvp -Name "mode_controller_run" -Arguments @($ModeVvp)
if ($modeRunExit -ne 0) {
    Write-Host "[FAIL] Mode-controller debounce/frame-boundary simulation failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Mode-controller debounce/frame-boundary simulation PASSED." -ForegroundColor Green

# Step 10: Run classifier four-state and LED exclusivity simulation
Write-Host "`n[10/10] Running Four-State Classifier/LED Simulation..." -ForegroundColor Yellow
$ClassifierVvp = Join-Path $VerificationOutput "tb_defect_classifier.vvp"
$classifierCompileExit = Invoke-CapturedTool -FilePath $iverilog -Name "defect_classifier_compile" -Arguments @(
    "-g2012", "-Wall", "-s", "tb_defect_classifier", "-o", $ClassifierVvp,
    "fallback/tb_defect_classifier.v", "fallback/rtl/defect_classifier.v"
)
if ($classifierCompileExit -ne 0) {
    Write-Host "[FAIL] Compilation of tb_defect_classifier.v failed!" -ForegroundColor Red
    exit 1
}
$classifierRunExit = Invoke-CapturedTool -FilePath $vvp -Name "defect_classifier_run" -Arguments @($ClassifierVvp)
if ($classifierRunExit -ne 0) {
    Write-Host "[FAIL] Four-state classifier/LED simulation failed!" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Four-state classifier/LED simulation PASSED." -ForegroundColor Green

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ">>> ALL INDUSTRIAL INSPECTION TESTS COMPLETED SUCCESSFULLY (100% PASS) <<<" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
exit 0
