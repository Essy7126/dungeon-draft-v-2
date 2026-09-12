#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath='', [switch]$Verify, [switch]$RealAudio)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$godot=Resolve-DevGodot $GodotPath
foreach($sound in @('strike','guard','shot','dash')) {
    if(-not (Test-Path -LiteralPath (Join-Path $root "artifacts/audio/soft_v5/$sound.wav"))) {
        throw 'Sons absents : exécuter tools/audio_workshop/build_soft_trial.py.'
    }
}
if(-not (Test-Path -LiteralPath (Join-Path $root 'artifacts/audio/music_mystery_v1/mysterious_harp.wav'))) {
    throw 'Musique absente : exécuter tools/audio_workshop/build_mysterious_music.py.'
}
$reports=New-DevRun 'audio-combat-trial'
$userdata=Join-Path $reports 'userdata'
[IO.Directory]::CreateDirectory($userdata) | Out-Null
$relative='res://' + [IO.Path]::GetRelativePath($root,$reports).Replace('\','/')
$environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata;XDG_DATA_HOME=$userdata}
$audioDriver=if($Verify -and -not $RealAudio){'Dummy'}else{'WASAPI'}
$arguments=@('--path',$root,'--audio-driver',$audioDriver,'--rendering-method','gl_compatibility','--resolution','1600x900',
    '--log-file',(Join-Path $reports 'trial.engine.log'),'res://tools/audio_workshop/AudioCombatTrial.tscn',
    '--',"--explorer-output=$relative",'--explorer-node=d01_0','--explorer-seed=2401','--explorer-mode=play')
if($Verify) {
    $engineLock=$null
    try {
        $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--import') $root $reports 'import' 240 $environment
        $errors=@(Get-DevEngineErrors $reports 'import' | Sort-Object -Unique)
        if(-not (Test-DevProcessSuccess $import) -or $errors.Count -gt 0){throw "Import failed: $($errors -join ' | ')"}
        $arguments=@('--position','-3000,-3000') + $arguments + @('--audio-verify')
        if($RealAudio){$arguments+=@('--audio-real-output')}
        $result=Invoke-DevProcess $godot $arguments $root $reports 'trial' 120 $environment
        $errors=@(Get-DevEngineErrors $reports 'trial' | Sort-Object -Unique)
        $reportPath=Join-Path $reports 'audio-verification.json'
        $report=if(Test-Path $reportPath){Get-Content $reportPath -Raw | ConvertFrom-Json}else{$null}
        $captures=@(Get-ChildItem $reports -Filter 'capture-*.png')
        $passed=(Test-DevProcessSuccess $result) -and $null -ne $report -and $report.passed -and $report.count -gt 0 -and $captures.Count -gt 0 -and $errors.Count -eq 0
        Write-DevJson (Join-Path $reports 'summary.json') @{passed=$passed;errors=$errors;report=$report;reports=$reports}
        Get-Content (Join-Path $reports 'summary.json')
        if(-not $passed){exit 1}
    } catch {
        Write-DevJson (Join-Path $reports 'summary.json') @{passed=$false;error=$_.Exception.Message;reports=$reports}
        throw
    } finally {
        if($engineLock){$engineLock.Dispose()}
    }
} else {
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$godot
    $start.WorkingDirectory=$root
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
    foreach($key in $environment.Keys){$start.Environment[$key]=$environment[$key]}
    $process=[Diagnostics.Process]::Start($start)
    @{started=$true;pid=$process.Id;reports=$reports} | ConvertTo-Json
}
