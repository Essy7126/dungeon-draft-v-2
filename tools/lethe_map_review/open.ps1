#requires -Version 7.2
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$reports=New-DevRun 'lethe-traces-play'
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=Resolve-DevGodot ''
$start.WorkingDirectory=$root
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$userdata=Join-Path $reports 'userdata'
[IO.Directory]::CreateDirectory($userdata)|Out-Null
foreach($key in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME')){$start.Environment[$key]=$userdata}
foreach($argument in @('--path',$root,'--rendering-method','gl_compatibility','--resolution','1600x900','--log-file',(Join-Path $reports 'play.engine.log'),'res://tools/combat_da_review/Review.tscn','--','--room=res://data/rooms/catabase_routes/route_f51a86b714b9/room.tres')){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
@{started=$true;pid=$process.Id;reports=$reports}|ConvertTo-Json
