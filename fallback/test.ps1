param([string]$IcarusBin = '')
$ErrorActionPreference='Stop'
$env:PATHEXT='.COM;.EXE;.BAT;.CMD' 
$taskRoot=$PSScriptRoot
$oldStamp=Join-Path $taskRoot 'test-input-manifest.json'
if(Test-Path -LiteralPath $oldStamp){Remove-Item -LiteralPath $oldStamp}
$repoRoot=Split-Path $taskRoot -Parent
. (Join-Path $taskRoot 'input-manifest.ps1')
$inputSnapshot=Get-IndustrialInputManifest $taskRoot | ConvertTo-Json -Depth 4
if(!$IcarusBin){$IcarusBin=Join-Path $repoRoot '.tools/iverilog/bin'}
$rtl=Join-Path $taskRoot 'project/user_source/hdl_source'
$td=Join-Path $taskRoot 'project/td_project'
$resultDir=Join-Path $taskRoot 'test-results'
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null
$sourcePairs=@(
 @('color_detect_96.v',"$rtl/isp/color_detect_96.v"),
 @('industrial_overlay_96.v',"$rtl/isp/industrial_overlay_96.v"),
 @('box_draw_96.v',"$td/box_draw_96.v"),
 @('data_96bit_to_128bit.v',"$rtl/data_96bit_to_128bit.v")
)
foreach($pair in $sourcePairs){
 if((Get-FileHash -LiteralPath (Join-Path $taskRoot "rtl/$($pair[0])")).Hash -ne (Get-FileHash -LiteralPath $pair[1]).Hash){throw "RTL/project mismatch: $($pair[0])"}
}
$tests=@('tb_industrial','tb_colors','tb_full_frame','tb_box','tb_pack','tb_pack_line','tb_pipeline','tb_awb_tags','tb_isp')
foreach($test in $tests){
 $compiled=Join-Path $resultDir "$test.vvp"
 $sources=@("$rtl/isp/color_detect_96.v","$rtl/isp/industrial_overlay_96.v","$td/box_draw_96.v","$rtl/data_96bit_to_128bit.v",(Join-Path $taskRoot "tests/$test.v"))
 if($test -eq 'tb_isp'){$sources=@("$rtl/isp/isp_top.v","$rtl/isp/data128_96/data128_96.v","$td/import/edge_detect_96.v","$rtl/isp/color_detect_96.v","$rtl/isp/industrial_overlay_96.v","$td/box_draw_96.v","$rtl/data_96bit_to_128bit.v",(Join-Path $taskRoot 'tests/isp_dependency_models.v'),(Join-Path $taskRoot 'tests/tb_isp.v'))}
 if($test -eq 'tb_awb_tags'){$sources=@("$rtl/awb.v","$rtl/signal_delay.v",(Join-Path $taskRoot 'tests/awb_dependency_models.v'),(Join-Path $taskRoot 'tests/tb_awb_tags.v'))}
 try{
  & (Join-Path $IcarusBin 'iverilog.exe') -g2001 -s $test -o $compiled @sources
  if($LASTEXITCODE -ne 0){throw "Compile failed: $test"}
  & (Join-Path $IcarusBin 'vvp.exe') $compiled | Tee-Object -FilePath (Join-Path $resultDir "$test.log")
  if($LASTEXITCODE -ne 0){throw "Simulation failed: $test"}
 }finally{if(Test-Path -LiteralPath $compiled){Remove-Item -LiteralPath $compiled}}
}
. (Join-Path $taskRoot 'input-manifest.ps1')
$currentSnapshot=Get-IndustrialInputManifest $taskRoot | ConvertTo-Json -Depth 4
if($inputSnapshot -ne $currentSnapshot){throw 'Inputs changed during regression tests'}
$inputSnapshot | Set-Content -LiteralPath (Join-Path $taskRoot 'test-input-manifest.json') -Encoding UTF8
Write-Output 'PASS all industrial regression tests against TD project sources'
