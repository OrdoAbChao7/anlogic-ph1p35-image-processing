<#
.SYNOPSIS
    FPGA Agent Development Loop - Unified PowerShell Command Line Entry.
.DESCRIPTION
    Wraps python -m fpga_loop for seamless execution on Windows.
.EXAMPLE
    .\scripts\fpga-loop.ps1 doctor
    .\scripts\fpga-loop.ps1 test --regressions
    .\scripts\fpga-loop.ps1 run --module color_detect_96
    .\scripts\fpga-loop.ps1 report
#>

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command = "doctor",

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$RemainingArgs
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$env:PYTHONPATH = "$repoRoot;$env:PYTHONPATH"

$pyArgs = @("-m", "work.fpga_loop", $Command) + $RemainingArgs
& python @pyArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
