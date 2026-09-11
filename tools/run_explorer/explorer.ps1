#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath='', [switch]$AfterCombat)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$godot=Resolve-DevGodot $GodotPath
$reports=New-DevRun 'run-explorer'
$start=[Diagnostics.ProcessStartInfo]::new()
$start.FileName=$godot
$start.WorkingDirectory=$root
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$scene=if($AfterCombat){'res://tools/run_explorer/RunExplorerPreview.tscn'}else{'res://tools/run_explorer/RunExplorer.tscn'}
foreach($argument in @('--path',$root,'--rendering-method','gl_compatibility','--resolution','1600x900','--log-file',(Join-Path $reports 'explorer.log'),$scene)) {
    $start.ArgumentList.Add($argument)
}
if($AfterCombat){
    $userdata=Join-Path $reports 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    foreach($key in @('APPDATA','LOCALAPPDATA','XDG_DATA_HOME')){$start.Environment[$key]=$userdata}
    $relative='res://' + [IO.Path]::GetRelativePath($root,$reports).Replace('\','/')
    foreach($argument in @('--',"--explorer-output=$relative",'--explorer-node=d01_0','--explorer-seed=2401','--explorer-mode=aftermath')){$start.ArgumentList.Add($argument)}
}
$process=[Diagnostics.Process]::Start($start)
@{started=$true;pid=$process.Id;reports=$reports} | ConvertTo-Json
