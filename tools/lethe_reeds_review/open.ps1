#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath='')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$reports=New-DevRun 'lethe-reeds-play'
$relative='res://'+[IO.Path]::GetRelativePath($root,$reports).Replace('\','/')
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=Resolve-DevGodot $GodotPath
$start.WorkingDirectory=$root
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$userdata=Join-Path $reports 'userdata'
[IO.Directory]::CreateDirectory($userdata)|Out-Null
foreach($key in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME')){$start.Environment[$key]=$userdata}
foreach($argument in @(
    '--path',$root,'--single-window','--rendering-method','gl_compatibility',
    '--resolution','1600x900','--log-file',(Join-Path $reports 'play.engine.log'),
    'res://tools/run_explorer/RunExplorerPreview.tscn','--',
    "--explorer-output=$relative",'--explorer-seed=2401','--explorer-node=d05_1','--explorer-mode=play'
)){$start.ArgumentList.Add($argument)}
$process=[Diagnostics.Process]::Start($start)
@{started=$true;pid=$process.Id;node_id='d05_1';seed=2401;reports=$reports;validation_performed=$false}|ConvertTo-Json
