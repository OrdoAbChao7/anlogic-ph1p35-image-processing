$ErrorActionPreference = 'Stop'

$gateRoot = $PSScriptRoot
$tdExe    = 'E:\Projects\FPGA\.tools\td\app\bin\td_commands_prompt.exe'
$flowTcl  = Join-Path $gateRoot 'exit_after_default_flow.tcl'

if (-not (Test-Path -LiteralPath $tdExe)) { throw "TD executable missing: $tdExe" }
if (Get-Process -Name 'td_commands_prompt' -ErrorAction SilentlyContinue) {
    throw 'td_commands_prompt already running; refusing a duplicate Gate run.'
}

foreach ($arm in @('baseline','candidate')) {
    $syn = Join-Path $gateRoot "$arm\syn_1"
    foreach ($p in @(
        (Join-Path $syn 'settings.cfg'),
        (Join-Path $syn 'industrial_detect_gate.prj'),
        (Join-Path $syn '..\industrial_detect_gate_top.v'),
        (Join-Path $syn '..\color_detect_96_v2.v'),
        (Join-Path $syn '..\morph_open_96.v'),
        (Join-Path $gateRoot 'industrial_detect_gate.sdc'))) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Missing $arm Gate input: $p" }
    }
    foreach ($a in @('td_gate_stdout.log','td_gate_stderr.log','flow.status','.opt_gate.end.f','gate.qor',
                     'industrial_detect_gate_gate.area','industrial_detect_gate_gate.timing')) {
        $ap = Join-Path $syn $a
        if (Test-Path -LiteralPath $ap) { throw "Refusing to overwrite Gate output: $ap" }
    }

    $arg = $flowTcl.Replace('\','/')
    $proc = Start-Process -FilePath $tdExe -ArgumentList $arg `
        -WorkingDirectory $syn -PassThru -Wait -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $syn 'td_gate_stdout.log') `
        -RedirectStandardError  (Join-Path $syn 'td_gate_stderr.log')

    Write-Output "TD_GATE_ARM=$arm EXIT_CODE=$($proc.ExitCode)"
    if ($proc.ExitCode -ne 0) { throw "$arm Gate failed; raw logs preserved in $syn" }
    if (-not (Test-Path -LiteralPath (Join-Path $syn '.opt_gate.end.f'))) {
        throw "$arm Gate omitted the opt_gate completion marker; raw logs preserved in $syn"
    }
    foreach ($r in @('gate.qor','industrial_detect_gate_gate.area','industrial_detect_gate_gate.timing')) {
        if (-not (Test-Path -LiteralPath (Join-Path $syn $r))) {
            throw "$arm Gate output missing $r; raw logs preserved in $syn"
        }
    }
}
Write-Output 'TD_GATE_AB_COMPLETE'
