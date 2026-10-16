function Get-IndustrialInputManifest([string]$TaskRoot){
 $files=@()
 foreach($dir in @('project/user_source','project/td_project/import','project/td_project/al_ip','build-inputs','rtl','tests')){
  $files+=@(Get-ChildItem -LiteralPath (Join-Path $TaskRoot $dir) -File -Recurse)
 }
 foreach($name in @('camera_to_dsi_display.al','camera_to_dsi_display.sdc','box_draw_96.v')){
  $files+=Get-Item -LiteralPath (Join-Path $TaskRoot "project/td_project/$name")
 }
 foreach($name in @('build.ps1','test.ps1','export.ps1','input-manifest.ps1')){$files+=Get-Item -LiteralPath (Join-Path $TaskRoot $name)}
 return @($files | Sort-Object FullName | ForEach-Object {
  [ordered]@{path=$_.FullName.Substring([IO.Path]::GetFullPath($TaskRoot).Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
 })
}
