param(
    [Parameter(Mandatory=$true)][string]$Exp
)
$ErrorActionPreference = 'Stop'

$tdExe = 'E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe'
$exp   = (Resolve-Path -LiteralPath $Exp).Path
$runs  = Join-Path $exp 'td_project\camera_to_dsi_display_Runs'
$src   = Join-Path $runs 'phy_1'
$dst   = Join-Path $runs 'phy_bitgen'

if (Get-Process -Name 'td_commands_prompt' -ErrorAction SilentlyContinue) {
    throw 'td_commands_prompt already running; refusing a duplicate bitgen run.'
}
foreach ($f in @('camera_to_dsi_display.prj','camera_to_dsi_display_pr.db','final_timing.rpt','route.qor')) {
    if (-not (Test-Path -LiteralPath (Join-Path $src $f))) { throw "route artifact missing: $f" }
}
if (Test-Path -LiteralPath $dst) { throw "refusing: $dst already exists" }

# Refuse to bitgen a database whose own report is not timing-clean.
$qor = Get-Content -LiteralPath (Join-Path $src 'route.qor')
$wns = ($qor | Select-String -Pattern 'Setup WNS\s*\|\s*(-?\d+)').Matches[0].Groups[1].Value
$tns = ($qor | Select-String -Pattern 'Setup TNS\s*\|\s*(-?\d+)').Matches[0].Groups[1].Value
$hwn = ($qor | Select-String -Pattern 'Hold WNS\s*\|\s*(-?\d+)').Matches[0].Groups[1].Value
$htn = ($qor | Select-String -Pattern 'Hold TNS\s*\|\s*(-?\d+)').Matches[0].Groups[1].Value
$sep = ($qor | Select-String -Pattern 'violated S-EP\s*\|\s*(\d+)').Matches[0].Groups[1].Value
Write-Output "ROUTE Timing: SWNS=$wns STNS=$tns HWNS=$hwn HTNS=$htn SEP=$sep"
if (([int]$wns -lt 0) -or ([int]$tns -ne 0) -or ([int]$hwn -lt 0) -or ([int]$htn -ne 0) -or ([int]$sep -ne 0)) {
    throw 'refusing to bitgen a database that is not timing-clean'
}

New-Item -ItemType Directory -Path $dst | Out-Null
Copy-Item -LiteralPath (Join-Path $src 'camera_to_dsi_display.prj') -Destination $dst
Copy-Item -LiteralPath (Join-Path $src 'camera_to_dsi_display_pr.db') -Destination $dst
@'
set SDCList {"../../camera_to_dsi_display.sdc"}
set area_option -packarea
set device_name ph1_35p.db
set end_step bitgen
set package_name PH1P35MDG324
set prj_name {camera_to_dsi_display}
set run_type phy
set speed 3
set start_step bitgen
set top_model_name {design_top_wrapper}
'@ | Set-Content -LiteralPath (Join-Path $dst 'settings.cfg') -Encoding ascii

$flow = (Join-Path $exp 'run_flow_exit.tcl').Replace('\','/')
$p = Start-Process -FilePath $tdExe -ArgumentList $flow -WorkingDirectory $dst `
    -PassThru -Wait -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $dst 'td_wrapper_stdout.log') `
    -RedirectStandardError  (Join-Path $dst 'td_wrapper_stderr.log')
Write-Output "BITGEN_EXIT=$($p.ExitCode)"
if ($p.ExitCode -ne 0) { throw 'bitgen failed; raw logs preserved' }
if (-not (Test-Path -LiteralPath (Join-Path $dst '.bitgen.end.f'))) { throw 'bitgen completion marker missing' }

$bit = Join-Path $dst 'camera_to_dsi_display.bit'
$cmp = Join-Path $dst 'camera_to_dsi_display_compress.bit'
foreach ($b in @($bit,$cmp)) {
    $i = Get-Item -LiteralPath $b
    "{0}  {1}  {2}" -f (Get-FileHash -LiteralPath $b -Algorithm SHA256).Hash, $i.Length, $i.Name
}
Write-Output 'BITGEN_COMPLETE'
