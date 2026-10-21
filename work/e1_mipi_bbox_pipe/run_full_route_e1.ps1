$ErrorActionPreference = 'Stop'

$exp    = $PSScriptRoot
$tdExe  = 'E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe'
$flow   = Join-Path $exp 'run_flow_exit_e1.tcl'
$runs   = Join-Path $exp 'td_project\camera_to_dsi_display_Runs'

if (-not (Test-Path -LiteralPath $tdExe)) { throw "TD executable missing: $tdExe" }
if (Get-Process -Name 'td_commands_prompt' -ErrorAction SilentlyContinue) {
    throw 'td_commands_prompt already running; refusing a duplicate run.'
}

foreach ($arm in @('syn_1','phy_1')) {
    $dir = Join-Path $runs $arm
    foreach ($a in @('gate.qor','route.qor','flow.status','place_flow.status','route_flow.status',
                     'camera_to_dsi_display_phy.ts','final_timing.rpt')) {
        if (Test-Path -LiteralPath (Join-Path $dir $a)) {
            throw "Refusing to overwrite existing result $arm/$a"
        }
    }
    $arg = $flow.Replace('\','/')
    $p = Start-Process -FilePath $tdExe -ArgumentList $arg -WorkingDirectory $dir `
        -PassThru -Wait -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $dir 'td_wrapper_stdout.log') `
        -RedirectStandardError  (Join-Path $dir 'td_wrapper_stderr.log')
    Write-Output "FULLTOP_ARM=$arm EXIT_CODE=$($p.ExitCode)"
    if ($p.ExitCode -ne 0) { throw "$arm full-top run failed; raw logs preserved in $dir" }
}

# phy flow writes final_timing.rpt only through report_timing_summary; confirm the
# terminal timing status exists before declaring the Route arm complete.
$ts = Join-Path $runs 'phy_1\camera_to_dsi_display_phy.ts'
if (-not (Test-Path -LiteralPath $ts)) { throw "Route timing status missing: $ts" }
Write-Output 'FULLTOP_ROUTE_COMPLETE'
Get-Content -LiteralPath $ts
