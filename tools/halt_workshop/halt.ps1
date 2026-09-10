#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Position=0)][ValidateSet('new','attach','check','prepare','open','verify','test')][string]$Command='open',
    [string]$Map='res://data/halts/emerald_sanctuary_v1.json',
    [string]$Id='',
    [ValidateSet('sanctuary','merchant','hub','lore')][string]$Kind='sanctuary',
    [string]$Brief='',
    [string]$Image='',
    [string]$GodotPath='',
    [string]$PythonPath='',
    [switch]$Record
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=$null
$engineLock=$null
try {
    if ($Command -in @('new','attach','check','prepare','test')) {
        if (-not $PythonPath) {
            $pythonCommand=Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonCommand) {throw 'Python 3.10+ with Pillow required. Use -PythonPath.'}
            $PythonPath=$pythonCommand.Source
        }
        $runRoot=New-DevRun "halt-$Command"
        $arguments=@('-X','utf8',(Join-Path $PSScriptRoot 'halt_workshop.py'),$Command)
        switch ($Command) {
            'new' {$arguments+=@($Id,'--kind',$Kind,'--brief',$Brief)}
            'attach' {$arguments+=@($Id,$Image)}
            'test' {$arguments=@('-X','utf8','-m','unittest','discover','-s','tools/halt_workshop','-p','test_*.py','-v')}
            default {$arguments+=@($Map)}
        }
        $result=Invoke-DevProcess $PythonPath $arguments $root $runRoot 'prepare' 60
        $passed=Test-DevProcessSuccess $result
        $summary=@{passed=$passed;command=$Command;reports=$runRoot}
        Write-DevJson (Join-Path $runRoot 'summary.json') $summary
        Get-Content -LiteralPath (Join-Path $runRoot 'prepare.stdout.log')
        if (-not $passed) {Get-Content -LiteralPath (Join-Path $runRoot 'prepare.stderr.log')}
        $summary | ConvertTo-Json
        exit $(if($passed){0}else{1})
    }
    $godot=Resolve-DevGodot $GodotPath
    if ($Command -eq 'open') {
        # This command explicitly opens the playable study for the user.
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=$godot; $start.WorkingDirectory=$root
        $start.UseShellExecute=$false; $start.CreateNoWindow=$true
        foreach ($argument in @('--path',$root,'--rendering-method','gl_compatibility','--resolution','1600x900','res://hub/painted_halt/LivingHalt.tscn','--',"--halt-manifest=$Map")) {
            $start.ArgumentList.Add($argument)
        }
        $process=[Diagnostics.Process]::Start($start)
        @{started=$true;pid=$process.Id;map=$Map;validation_performed=$false} | ConvertTo-Json
        exit 0
    }
    $runRoot=New-DevRun 'halt-verify'
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $userdata=Join-Path $runRoot 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata}
    $version=Invoke-DevProcess $godot @('--version') $root $runRoot 'version' 15
    $versionText=(Get-Content -LiteralPath (Join-Path $runRoot 'version.stdout.log') -Raw).Trim()
    if (-not(Test-DevProcessSuccess $version) -or $versionText -notmatch (Get-DevToolchain).godot_version_pattern) {throw 'Incorrect Godot version.'}
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $runRoot 'import.engine.log'),'--import') $root $runRoot 'import' 240 $environment
    $errors=@(Get-DevEngineErrors $runRoot 'import' | Sort-Object -Unique)
    if (-not(Test-DevProcessSuccess $import) -or $errors.Count -gt 0) {throw "Import failed: $($errors -join ' | ')"}
    $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--log-file',(Join-Path $runRoot 'verify.engine.log'),'res://tools/halt_workshop/VerifyLivingHalt.tscn','--',"--halt-manifest=$Map","--output-root=$runRoot")
    if($Record){$arguments+='--record'}
    $result=Invoke-DevProcess $godot $arguments $root $runRoot 'verify' 300 $environment
    $errors=@(Get-DevEngineErrors $runRoot 'verify' | Sort-Object -Unique)
    $reportPath=Join-Path $runRoot 'verification.json'
    if (-not(Test-Path -LiteralPath $reportPath)) {throw 'Missing rendered report: validation incomplete.'}
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $passed=(Test-DevProcessSuccess $result) -and $report.passed -and $report.rendered -and $report.check_count -gt 0 -and $report.movement_samples -gt 0 -and $report.captures.Count -gt 0 -and $errors.Count -eq 0
    $summary=@{passed=$passed;command=$Command;checks=$report.check_count;captures=$report.captures.Count;movement_samples=$report.movement_samples;unsafe_samples=$report.unsafe_samples;errors=$errors;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 5
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    if($runRoot){Write-DevJson (Join-Path $runRoot 'summary.json') $summary}
    $summary | ConvertTo-Json
    exit 1
} finally {
    if($engineLock){$engineLock.Dispose()}
}
