param(
    [Parameter(Mandatory=$true)][string]$Exp,
    [string]$FlowTclName = 'run_flow_exit.tcl',
    [switch]$RequireClean
)
$ErrorActionPreference = 'Stop'

$tdExe = 'E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe'
$exp   = (Resolve-Path -LiteralPath $Exp).Path
$flow  = Join-Path $exp $FlowTclName
$runs  = Join-Path $exp 'td_project\camera_to_dsi_display_Runs'

if (-not (Test-Path -LiteralPath $tdExe)) { throw "TD executable missing: $tdExe" }
if (-not (Test-Path -LiteralPath $flow))  { throw "Flow tcl missing: $flow" }
if (Get-Process -Name 'td_commands_prompt' -ErrorAction SilentlyContinue) {
    throw 'td_commands_prompt already running; refusing a duplicate run.'
}

foreach ($arm in @('syn_1','phy_1')) {
    $dir = Join-Path $runs $arm
    if ($RequireClean) {
        foreach ($a in @('gate.qor','route.qor','flow.status','place_flow.status','route_flow.status',
                         'camera_to_dsi_display_phy.ts','final_timing.rpt','camera_to_dsi_display.bit')) {
            if (Test-Path -LiteralPath (Join-Path $dir $a)) {
                throw "Refusing to overwrite existing result $arm/$a"
            }
        }
    }
    $arg = $flow.Replace('\','/')
    $t0  = Get-Date
    $p = Start-Process -FilePath $tdExe -ArgumentList $arg -WorkingDirectory $dir `
        -PassThru -Wait -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $dir 'td_wrapper_stdout.log') `
        -RedirectStandardError  (Join-Path $dir 'td_wrapper_stderr.log')
    $dt = (Get-Date) - $t0
    Write-Output ("FULLTOP_ARM={0} EXIT_CODE={1} WALL={2:mm\:ss}" -f $arm, $p.ExitCode, $dt)
    if ($p.ExitCode -ne 0) { throw "$arm run failed; raw logs preserved in $dir" }
}

$ts = Join-Path $runs 'phy_1\camera_to_dsi_display_phy.ts'
if (Test-Path -LiteralPath $ts) {
    Write-Output '--- phy timing status ---'
    Get-Content -LiteralPath $ts
}
$q = Join-Path $runs 'phy_1\route.qor'
if (Test-Path -LiteralPath $q) {
    Write-Output '--- route qor ---'
    Get-Content -LiteralPath $q
}
Write-Output 'FULLTOP_COMPLETE'
