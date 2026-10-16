param([string]$OutputDir='')
$ErrorActionPreference='Stop'
$taskRoot=$PSScriptRoot
. (Join-Path $taskRoot 'input-manifest.ps1')
# The exporter does not participate in TD or simulation. Keep the original
# successful snapshots intact; only this verifier's exact path is excluded.
# Its released bytes are still included in the final package manifest.
$currentRecords=Get-IndustrialInputManifest $taskRoot
$currentMap=@{}
foreach($entry in $currentRecords){
 if($entry.path -ceq 'export.ps1'){continue}
 if($currentMap.ContainsKey($entry.path)){throw 'Duplicate current input path'}
 $currentMap[$entry.path]=$entry.sha256
}
foreach($stamp in @('build-input-manifest.json','test-input-manifest.json')){
 $savedRecords=Get-Content -LiteralPath (Join-Path $taskRoot $stamp) -Raw | ConvertFrom-Json
 $savedMap=@{}
 foreach($entry in $savedRecords){
  if($entry.path -ceq 'export.ps1'){continue}
  if($savedMap.ContainsKey($entry.path)){throw "Duplicate saved input path in $stamp"}
  $savedMap[$entry.path]=$entry.sha256
 }
 if($currentMap.Count -ne $savedMap.Count){throw "Input set changed since $stamp"}
 foreach($path in $currentMap.Keys){
  if(!$savedMap.ContainsKey($path) -or $currentMap[$path] -ne $savedMap[$path]){throw "Inputs changed since $stamp : $path"}
 }
}
if(!$OutputDir){$OutputDir=Join-Path $taskRoot 'release/industrial-color-bbox-20261014'}
$phy=Join-Path $taskRoot 'project/td_project/camera_to_dsi_display_Runs/phy_1'
$syn=Join-Path $taskRoot 'project/td_project/camera_to_dsi_display_Runs/syn_1'
$outputStamp=Get-Content -LiteralPath (Join-Path $taskRoot 'build-output-manifest.json') -Raw | ConvertFrom-Json
if($outputStamp.bit_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $phy 'camera_to_dsi_display.bit') -Algorithm SHA256).Hash -or $outputStamp.qor_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $phy 'route.qor') -Algorithm SHA256).Hash){throw 'Bitstream or final timing report differs from successful build credential'}
if(!(Test-Path -LiteralPath (Join-Path $phy '.bitgen.end.f'))){throw 'No completed bitgen'}
$qor=[IO.File]::ReadAllText((Join-Path $phy 'route.qor'))
function Metric([string]$name){
 $match=[regex]::Match($qor,'\|\s*'+[regex]::Escape($name)+'\s*\|\s*(-?\d+)')
 if(!$match.Success){throw "Missing final metric: $name"}
 return [int]$match.Groups[1].Value
}
$setupWns=Metric 'Setup WNS';$setupTns=Metric 'Setup TNS'
$holdWns=Metric 'Hold WNS';$holdTns=Metric 'Hold TNS'
if($setupWns -lt 0 -or $holdWns -lt 0 -or $setupTns -ne 0 -or $holdTns -ne 0){throw 'Final timing failed; export rejected'}
foreach($test in @('tb_industrial','tb_colors','tb_full_frame','tb_box','tb_pack','tb_pack_line','tb_pipeline','tb_awb_tags','tb_isp')){
 $log=Join-Path $taskRoot "test-results/$test.log"
 if(!(Test-Path -LiteralPath $log) -or !([IO.File]::ReadAllText($log).Contains('PASS '))){throw "Missing passing regression: $test"}
}
if(Test-Path -LiteralPath $OutputDir){throw 'OutputDir already exists. Use a new version directory.'}
New-Item -ItemType Directory -Path "$OutputDir/project/td_project" -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskRoot 'project/user_source') -Destination "$OutputDir/project/user_source" -Recurse
foreach($dir in @('al_ip','import')){Copy-Item -LiteralPath (Join-Path $taskRoot "project/td_project/$dir") -Destination "$OutputDir/project/td_project/$dir" -Recurse}
foreach($f in @('camera_to_dsi_display.al','camera_to_dsi_display.sdc','box_draw_96.v')){Copy-Item -LiteralPath (Join-Path $taskRoot "project/td_project/$f") -Destination "$OutputDir/project/td_project/$f"}
foreach($dir in @('rtl','tests','build-inputs')){Copy-Item -LiteralPath (Join-Path $taskRoot $dir) -Destination (Join-Path $OutputDir $dir) -Recurse}
foreach($f in @('README.md','build.ps1','test.ps1','export.ps1','input-manifest.ps1','build-input-manifest.json','test-input-manifest.json','build-output-manifest.json')){Copy-Item -LiteralPath (Join-Path $taskRoot $f) -Destination (Join-Path $OutputDir $f)}
New-Item -ItemType Directory -Path "$OutputDir/reports" -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $taskRoot 'test-results') -Destination "$OutputDir/test-results" -Recurse
foreach($f in @('route.qor','route_flow.status','route_clock_utilization.txt','console.log','stderr.log','camera_to_dsi_display_pr.timing','final_timing.rpt','camera_to_dsi_display_phy.area')){
 $file=Join-Path $phy $f
 if(Test-Path -LiteralPath $file){Copy-Item -LiteralPath $file -Destination "$OutputDir/reports/$f"}
}
Copy-Item -LiteralPath (Join-Path $syn 'console.log') -Destination "$OutputDir/reports/synthesis.log"
Copy-Item -LiteralPath (Join-Path $phy 'camera_to_dsi_display.bit') -Destination "$OutputDir/industrial_color_bbox.bit"
$summary=[ordered]@{status='BUILD_PASS_CANDIDATE_PENDING_BOARD';device='PH1P35MDG324';td_version='6.2.168116';top='design_top_wrapper';setup_wns_ps=$setupWns;setup_tns_ps=$setupTns;hold_wns_ps=$holdWns;hold_tns_ps=$holdTns;slices=(Metric '#slices');rams=(Metric '#RAMs');dsps=(Metric '#DSPs');bit_sha256=(Get-FileHash -LiteralPath "$OutputDir/industrial_color_bbox.bit" -Algorithm SHA256).Hash;hardware_verified=$false;visual_approved=$false}
$summary | ConvertTo-Json | Set-Content -LiteralPath "$OutputDir/build-summary.json" -Encoding UTF8
$warnings=@([IO.File]::ReadAllLines((Join-Path $phy 'console.log')) | Where-Object {$_ -match 'WARNING|CRITICAL-WARNING'})
$warnings | Set-Content -LiteralPath "$OutputDir/reports/physical-warnings.txt" -Encoding UTF8
$manifest=@(Get-ChildItem -LiteralPath $OutputDir -File -Recurse | Sort-Object FullName | ForEach-Object {
 [ordered]@{path=$_.FullName.Substring([IO.Path]::GetFullPath($OutputDir).Length+1).Replace('\','/');size=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$OutputDir/manifest.json" -Encoding UTF8
Compress-Archive -Path (Join-Path $OutputDir '*') -DestinationPath "$OutputDir.zip" -CompressionLevel Optimal
Write-Output ($summary | ConvertTo-Json)
Write-Output "Exported source/report/download package: $OutputDir.zip"
