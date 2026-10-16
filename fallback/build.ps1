param([string]$TdRoot = '', [switch]$SynthesisOnly)
$ErrorActionPreference = 'Stop'
$env:PATHEXT='.COM;.EXE;.BAT;.CMD'
$taskRoot = $PSScriptRoot
$repoRoot = Split-Path $taskRoot -Parent
. (Join-Path $taskRoot 'input-manifest.ps1')
$inputSnapshot=Get-IndustrialInputManifest $taskRoot | ConvertTo-Json -Depth 4
foreach($stamp in @('build-input-manifest.json','build-output-manifest.json')){
 $oldStamp=Join-Path $taskRoot $stamp
 if(Test-Path -LiteralPath $oldStamp){Remove-Item -LiteralPath $oldStamp}
}
if (!$TdRoot) { $TdRoot = Join-Path $repoRoot '.tools/td/app' }
$tdExe = Join-Path $TdRoot 'bin/td_commands_prompt.exe'
$flow = (Join-Path $TdRoot 'doc/scripts/DefaultFlow.tcl').Replace('\','/')
if (!(Test-Path -LiteralPath $tdExe)) { throw 'TD executable missing. Supply -TdRoot.' }
$projectRoot = Join-Path $taskRoot 'project/td_project'
$alPath = Join-Path $projectRoot 'camera_to_dsi_display.al'
$alText = [IO.File]::ReadAllText($alPath)
$refs = [regex]::Matches($alText, '<File Path="([^"]+)"')
foreach ($ref in $refs) {
  $sourcePath = [IO.Path]::GetFullPath((Join-Path $projectRoot $ref.Groups[1].Value))
  if (!(Test-Path -LiteralPath $sourcePath)) { throw "Missing source: $sourcePath" }
}
$prjText = [regex]::Replace($alText, '<File Path="([^"]+)"', { param($m) '<File Path="../../' + $m.Groups[1].Value + '"' })
$phases = @('syn_1','phy_1')
if ($SynthesisOnly) { $phases = @('syn_1') }
foreach ($phase in $phases) {
  $runDir = Join-Path $projectRoot "camera_to_dsi_display_Runs/$phase"
  if (Test-Path -LiteralPath $runDir) {
    $resolved = [IO.Path]::GetFullPath($runDir)
    $allowed = [IO.Path]::GetFullPath($projectRoot) + [IO.Path]::DirectorySeparatorChar
    if (!$resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe clean path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
  }
  New-Item -ItemType Directory -Path $runDir -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $runDir 'camera_to_dsi_display.prj'),$prjText)
  Copy-Item -LiteralPath (Join-Path $taskRoot "build-inputs/$phase.cfg") -Destination (Join-Path $runDir 'settings.cfg')
  Push-Location $runDir
  try {
    $tdProcess = Start-Process -FilePath $tdExe -ArgumentList ('"' + $flow + '"') -WorkingDirectory $runDir -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $runDir 'console.log') -RedirectStandardError (Join-Path $runDir 'stderr.log')
    $tdExit = $tdProcess.ExitCode
    [IO.File]::WriteAllText((Join-Path $runDir 'exit-code.txt'),[string]$tdExit)
    if ($tdExit -ne 0) { throw "TD $phase failed: exit $tdExit. Inspect console.log." }
    $marker = if ($phase -eq 'syn_1') { '.opt_gate.end.f' } else { '.bitgen.end.f' }
    if (!(Test-Path -LiteralPath $marker)) { throw "TD $phase missing $marker" }
  } finally { Pop-Location }
  Write-Output "TD $phase complete"
}
if (!$SynthesisOnly) {
 $phy = Join-Path $projectRoot 'camera_to_dsi_display_Runs/phy_1'
 $bit = Join-Path $phy 'camera_to_dsi_display.bit'
 if (!(Test-Path -LiteralPath $bit)) { throw 'Bitstream missing' }
 $qor=[IO.File]::ReadAllText((Join-Path $phy 'route.qor'))
 foreach($metric in @('Setup WNS','Hold WNS','Setup TNS','Hold TNS')){
  $m=[regex]::Match($qor,'\|\s*'+[regex]::Escape($metric)+'\s*\|\s*(-?\d+)')
  if(!$m.Success){throw "Missing final metric: $metric"}
  $value=[int]$m.Groups[1].Value
  if(($metric -like '*WNS' -and $value -lt 0) -or ($metric -like '*TNS' -and $value -ne 0)){throw "Final timing failed: $metric=$value ps"}
 }
 $currentSnapshot=Get-IndustrialInputManifest $taskRoot | ConvertTo-Json -Depth 4
 if($inputSnapshot -ne $currentSnapshot){throw 'Build inputs changed during TD run'}
 $inputSnapshot | Set-Content -LiteralPath (Join-Path $taskRoot 'build-input-manifest.json') -Encoding UTF8
 $outputs=[ordered]@{bit_sha256=(Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash;qor_sha256=(Get-FileHash -LiteralPath (Join-Path $phy 'route.qor') -Algorithm SHA256).Hash}
 $outputs | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskRoot 'build-output-manifest.json') -Encoding UTF8
 Write-Output "Candidate bitstream: $bit"
 Write-Output ((Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash)
}
