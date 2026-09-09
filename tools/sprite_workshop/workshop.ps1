#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Position=0)][ValidateSet('open','seed','new','import','check','export','capture')][string]$Command='open',
    [string]$Clip='res://art/source/sprite_workshop/sentinelle_attack_e.json',
    [string]$Resource='',
    [string]$Animation='',
    [string]$Profile='',
    [string[]]$Frames=@(),
    [string]$Reference='',
    [string]$GodotPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=$null
$engineLock=$null
try {
    $godot=Resolve-DevGodot $GodotPath
    if ($Command -eq 'open') {
        # Interactive application explicitly requested by this command.
        $start=[Diagnostics.ProcessStartInfo]::new()
        $start.FileName=$godot
        $start.WorkingDirectory=$root
        $start.UseShellExecute=$false
        $start.CreateNoWindow=$true
        foreach($argument in @('--path',$root,'--rendering-method','gl_compatibility','--resolution','1440x900','res://tools/sprite_workshop/SpriteWorkshop.tscn','--',"--clip=$Clip")) {$start.ArgumentList.Add($argument)}
        $process=[Diagnostics.Process]::Start($start)
        @{started=$true;pid=$process.Id;clip=$Clip;validation_performed=$false} | ConvertTo-Json
        exit 0
    }
    $runRoot=New-DevRun "sprites-$Command"
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $reportPath=Join-Path $runRoot 'workshop.json'
    $arguments=@('--headless','--path',$root,'--log-file',(Join-Path $runRoot 'workshop.engine.log'),'res://tools/sprite_workshop/WorkshopCLI.tscn','--',"--command=$Command","--clip=$Clip","--resource=$Resource","--animation=$Animation","--profile=$Profile","--report=$reportPath")
    $arguments+=@("--frames=$(ConvertTo-Json -InputObject @($Frames) -Compress)","--reference=$Reference")
    if($Command -eq 'capture') {
        $arguments=@('--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1440x900') + @($arguments | Where-Object {$_ -ne '--headless'})
    }
    $process=Invoke-DevProcess $godot $arguments $root $runRoot 'workshop' 90 @{APPDATA=(Join-Path $runRoot 'userdata')}
    $errors=@(Get-DevEngineErrors $runRoot 'workshop' | Sort-Object -Unique)
    if(-not(Test-Path -LiteralPath $reportPath)){throw "Rapport absent : consulter $runRoot"}
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $passed=(Test-DevProcessSuccess $process) -and $report.ok -and $errors.Count -eq 0
    $summary=@{passed=$passed;command=$Command;errors=$errors;result=$report;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 14
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    if($runRoot){Write-DevJson (Join-Path $runRoot 'summary.json') $summary}
    $summary | ConvertTo-Json
    exit 1
} finally {
    if($engineLock){$engineLock.Dispose()}
}
