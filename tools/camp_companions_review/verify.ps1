#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$GodotPath='',
    [ValidateRange(0,60)][int]$WaitForEngineSeconds=55
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun 'camp-companions-production'
$engineLock=$null
try {
    $godot=Resolve-DevGodot $GodotPath
    $deadline=[DateTime]::UtcNow.AddSeconds($WaitForEngineSeconds)
    while (-not $engineLock) {
        try {$engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException] {if([DateTime]::UtcNow -ge $deadline){throw}; Start-Sleep -Milliseconds 500}
    }
    $userdata=Join-Path $runRoot 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata}
    $version=Invoke-DevProcess $godot @('--version') $root $runRoot 'version' 15 $environment
    $versionText=[IO.File]::ReadAllText((Join-Path $runRoot 'version.stdout.log')).Trim()
    if(-not(Test-DevProcessSuccess $version) -or $versionText -notmatch (Get-DevToolchain).godot_version_pattern){throw 'Godot version mismatch'}
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $runRoot 'import.engine.log'),'--import') $root $runRoot 'import' 240 $environment
    $importErrors=@(Get-DevEngineErrors $runRoot 'import' | Sort-Object -Unique)
    if(-not(Test-DevProcessSuccess $import) -or $importErrors.Count -gt 0){throw "Import failed: $($importErrors -join ' | ')"}
    $arguments=@('--verbose','--single-window','--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1920x1080','--log-file',(Join-Path $runRoot 'production.engine.log'),'res://tools/camp_companions_review/VerifyCampCompanions.tscn','--',"--production-output=$runRoot")
    $result=Invoke-DevProcess $godot $arguments $root $runRoot 'production' 240 $environment
    $errors=@(Get-DevEngineErrors $runRoot 'production' | Sort-Object -Unique)
    $reportPath=Join-Path $runRoot 'production_verification.json'
    if(-not(Test-Path -LiteralPath $reportPath)){throw 'Missing production report: validation incomplete.'}
    $report=Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json
    $missingCaptures=@($report.captures | Where-Object {-not(Test-Path -LiteralPath $_ -PathType Leaf)})
    $passed=(Test-DevProcessSuccess $result) -and $report.passed -and $report.rendered -and $report.check_count -ge 60 -and $report.captures.Count -ge 8 -and $missingCaptures.Count -eq 0 -and $errors.Count -eq 0 -and ('1920x1080' -in $report.resolutions) -and ('1280x720' -in $report.resolutions)
    $summary=@{passed=$passed;node_id=$report.node_id;checks=$report.check_count;captures=$report.captures.Count;errors=$errors;missing_captures=$missingCaptures;manual_visual_review_required=$true;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 6
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json
    exit 1
} finally {if($engineLock){$engineLock.Dispose()}}

