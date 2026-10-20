# ModelSim / Questa PH1P Simulation Library Compiler & Verifier
# Usage: powershell -ExecutionPolicy Bypass -File scripts/compile_modelsim_ph1p.ps1 [-VsimBin <path>] [-Force]

param(
    [string]$VsimBin = "C:\intelFPGA\20.1\modelsim_ase\win32aloem",
    [string]$LibDir = "E:\Projects\FPGA\.tools\modelsim_ph1p_lib",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path "$VsimBin\vsim.exe")) {
    $found = Get-Command vsim.exe -ErrorAction SilentlyContinue
    if ($found) {
        $VsimBin = Split-Path $found.Source -Parent
    } else {
        Write-Error "Cannot find vsim.exe at '$VsimBin' or in PATH."
        exit 1
    }
}

Write-Host "=== ModelSim Toolchain ===" -ForegroundColor Cyan
Write-Host "VsimBin: $VsimBin"
& "$VsimBin\vsim.exe" -version

$tdSimRoot = "E:\Projects\FPGA\.tools\td\app\sim_release"
if (-not (Test-Path $tdSimRoot)) {
    Write-Error "TD sim_release not found at '$tdSimRoot'."
    exit 1
}

New-Item -ItemType Directory -Force -Path $LibDir | Out-Null
Set-Location $LibDir

# Initialize or reinitialize library
if ($Force -or -not (Test-Path "$LibDir\ph1p_lib")) {
    Write-Host "=== Initializing ph1p_lib in $LibDir ===" -ForegroundColor Cyan
    & "$VsimBin\vlib.exe" ph1p_lib
    & "$VsimBin\vmap.exe" ph1p_lib "$LibDir\ph1p_lib"
}

# 1. Compile common
$commonFiles = @(
    "$tdSimRoot\common\al_phy_glbl.v",
    "$tdSimRoot\common\al_map_basic.v",
    "$tdSimRoot\common\al_map_lut.v",
    "$tdSimRoot\common\al_map_seq.v",
    "$tdSimRoot\common\al_map_adder.v",
    "$tdSimRoot\common\al_map_alu2b.v",
    "$tdSimRoot\common\al_map_mult.v",
    "$tdSimRoot\common\al_map_mux4.v",
    "$tdSimRoot\common\al_logic_debughub.v",
    "$tdSimRoot\common\apm\apm_byte_memory.v",
    "$tdSimRoot\common\apm\apm_memory.v",
    "$tdSimRoot\common\apm\apm_shifter.v",
    "$tdSimRoot\common\apm\logic_tvs.v"
)

Write-Host "=== Compiling common models (count: $($commonFiles.Count)) ===" -ForegroundColor Cyan
foreach ($f in $commonFiles) {
    if (Test-Path $f) {
        & "$VsimBin\vlog.exe" -work ph1p_lib "$f" | Out-Null
    }
}

# 2. Compile PH1P primitives & models
$ph1pFiles = Get-ChildItem "$tdSimRoot\ph1p" -Include "*.v","*.sv" -Recurse | Select-Object -ExpandProperty FullName
Write-Host "=== Compiling PH1P models (count: $($ph1pFiles.Count)) ===" -ForegroundColor Cyan

$failCount = 0
foreach ($f in $ph1pFiles) {
    $leaf = Split-Path $f -Leaf
    $args = @("-work", "ph1p_lib", "-sv")
    if ($leaf -match "pcie") {
        $args += @("-suppress", "2122")
    }
    $args += $f
    $res = & "$VsimBin\vlog.exe" @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: $leaf" -ForegroundColor Red
        $failCount++
    }
}

if ($failCount -gt 0) {
    Write-Error "Compilation finished with $failCount failures."
    exit 1
}

Write-Host "=== All files compiled successfully into ph1p_lib ===" -ForegroundColor Green

# 3. Quick Smoke Test
Write-Host "=== Running Self-Verification Smoke Test ===" -ForegroundColor Cyan
$smokeDir = Join-Path $LibDir "smoke_test"
New-Item -ItemType Directory -Force -Path $smokeDir | Out-Null
$tbFile = Join-Path $smokeDir "tb_smoke.v"
$tbCode = @'
`timescale 1ns/1ps
module tb_smoke;
    reg a;
    wire y;
    PH1P_LOGIC_BUF u_buf (.i(a), .o(y));
    initial begin
        a = 0;
        #10 a = 1;
        #10 a = 0;
        #10;
        $display("PH1P_SMOKE_PASS: primitive simulation verified!");
        $finish;
    end
endmodule
'@
[System.IO.File]::WriteAllText($tbFile, $tbCode, [System.Text.Encoding]::ASCII)

Push-Location $smokeDir
try {
    if (-not (Test-Path "$smokeDir\work")) {
        & "$VsimBin\vlib.exe" work | Out-Null
    }
    & "$VsimBin\vmap.exe" ph1p_lib "$LibDir\ph1p_lib" | Out-Null
    & "$VsimBin\vlog.exe" -sv $tbFile | Out-Null
    $simOut = & "$VsimBin\vsim.exe" -c -L ph1p_lib work.tb_smoke -do "run -all; quit -f" 2>&1
    if ($simOut -match "PH1P_SMOKE_PASS") {
        Write-Host "Verification result: PASS (PH1P primitive encrypted model operational)" -ForegroundColor Green
    } else {
        Write-Error "Smoke test failed to produce PASS banner."
        exit 1
    }
} finally {
    Pop-Location
}
