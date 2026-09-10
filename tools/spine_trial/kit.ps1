#requires -Version 7.2
param(
    [Parameter(Position=0)][ValidateSet('start','build','verify','godot')][string]$Command='start',
    [string]$Revision='sentinelle_kit_v7'
)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if($Revision -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Nom de révision invalide.'}
$python=Join-Path $projectRoot 'artifacts/dev-tools/sprite-python/Scripts/python.exe'
if($Command -eq 'build'){
    $buildArguments=@((Join-Path $PSScriptRoot 'sentinelle_kit.py'))
    if($PSBoundParameters.ContainsKey('Revision')){$buildArguments+=@('--revision',$Revision)}
    & $python @buildArguments
    exit $LASTEXITCODE
}
$bundle=Join-Path $projectRoot ('art/source/spine/'+$Revision)
$target=Join-Path $projectRoot ('artifacts/spine_trial/'+$Revision)
if(-not(Test-Path -LiteralPath $target)){
    if(-not(Test-Path -LiteralPath (Join-Path $bundle 'kit.json'))){throw 'Kit absent. Exécuter kit.ps1 build.'}
    Copy-Item -LiteralPath $bundle -Destination $target -Recurse
}
if(-not(Test-Path -LiteralPath (Join-Path $target 'kit.json'))){throw 'Manifeste du kit absent.'}
& (Join-Path $PSScriptRoot 'spine.ps1') start
if($LASTEXITCODE -ne 0){throw 'Le lecteur Spine ne démarre pas.'}
if($Command -eq 'verify'){
    & $python (Join-Path $PSScriptRoot 'verify_sentinelle_motion.py') $Revision
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
    & node (Join-Path $PSScriptRoot 'verify_kit_web.mjs') $Revision
    if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
    & (Join-Path $PSScriptRoot 'verify_kit.ps1') -Revision $Revision
    exit $LASTEXITCODE
}
if($Command -eq 'godot'){
    Import-Module (Join-Path $projectRoot 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
    & (Resolve-DevGodot) --path $projectRoot --rendering-method gl_compatibility --resolution 1200x896 res://tools/spine_trial/SentinelleKit.tscn -- ('--revision='+$Revision)
    exit $LASTEXITCODE
}
@{revision=$Revision;clips=24;review=('http://127.0.0.1:8734/files/'+$Revision+'/review.html');godot_scene='res://tools/spine_trial/SentinelleKit.tscn'} | ConvertTo-Json
exit 0
