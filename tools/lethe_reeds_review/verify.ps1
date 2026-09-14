#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$GodotPath='',
    [ValidateRange(30,600)][int]$TimeoutSeconds=180,
    [ValidateRange(0,60)][int]$WaitForEngineSeconds=55
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun 'lethe-reeds-review'
$room='res://data/rooms/catabase_routes/route_6d5efdb88ff0/room.tres'
$config='res://assets/catabase/combat/lethe_reeds_v1/visual_review.json'
$results=@()
$lock=$null
try {
    if(-not(Test-Path -LiteralPath (Join-Path $root ($config -replace '^res://','')) -PathType Leaf)) {
        throw "Calibration visuelle absente : $config. Placer les rectangles sur la peinture retenue avant cette revue."
    }
    $godot=Resolve-DevGodot $GodotPath
    $deadline=[DateTime]::UtcNow.AddSeconds($WaitForEngineSeconds)
    while(-not $lock) {
        try {$lock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException] {if([DateTime]::UtcNow -ge $deadline){throw}; Start-Sleep -Milliseconds 500}
    }
    $importUserdata=Join-Path $runRoot 'userdata-import'
    [IO.Directory]::CreateDirectory($importUserdata)|Out-Null
    $importEnvironment=@{APPDATA=$importUserdata;LOCALAPPDATA=$importUserdata;XDG_DATA_HOME=$importUserdata}
    $version=Invoke-DevProcess $godot @('--version') $root $runRoot 'version' 15 $importEnvironment
    $versionText=[IO.File]::ReadAllText((Join-Path $runRoot 'version.stdout.log')).Trim()
    if(-not(Test-DevProcessSuccess $version) -or $versionText -notmatch (Get-DevToolchain).godot_version_pattern){throw 'Godot version mismatch'}
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $runRoot 'import.engine.log'),'--import') $root $runRoot 'import' 240 $importEnvironment
    $importErrors=@(Get-DevEngineErrors $runRoot 'import'|Sort-Object -Unique)
    if(-not(Test-DevProcessSuccess $import) -or $importErrors.Count -gt 0){throw "Import failed: $($importErrors -join ' | ')"}
    $relative='res://'+[IO.Path]::GetRelativePath($root,$runRoot).Replace('\','/')
    foreach($size in @('1920x1080','1200x896')) {
        $label="review-$size"
        $userdata=Join-Path $runRoot "userdata-$size"
        [IO.Directory]::CreateDirectory($userdata)|Out-Null
        $environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata;XDG_DATA_HOME=$userdata}
        $arguments=@(
            '--path',$root,'--single-window','--rendering-method','gl_compatibility',
            '--audio-driver','Dummy','--position','-3000,-3000',
            '--log-file',(Join-Path $runRoot "$label.engine.log"),
            'res://tools/combat_da_review/Review.tscn','--',"--room=$room",
            "--capture=$relative/$label.png","--resolution=$size",'--production-qa','--reeds-visual-review'
        )
        if($size -eq '1200x896'){$arguments+="--compare-report=$relative/review-1920x1080.json"}
        $result=Invoke-DevProcess $godot $arguments $root $runRoot $label $TimeoutSeconds $environment
        $errors=@(Get-DevEngineErrors $runRoot $label|Sort-Object -Unique)
        $reportPath=Join-Path $runRoot "$label.json"
        $report=if(Test-Path -LiteralPath $reportPath){Get-Content -LiteralPath $reportPath -Raw -Encoding utf8|ConvertFrom-Json -AsHashtable}else{$null}
        $artifactsPresent=(Test-Path -LiteralPath (Join-Path $runRoot "$label.png")) -and (Test-Path -LiteralPath (Join-Path $runRoot "${label}_after_move_guard.png"))
        $oraclesPassed=$null -ne $report -and $report.ok -eq $true -and
            $report.room -eq $room -and $report.production_qa.ok -eq $true -and
            $report.painted_decor.ok -eq $true -and $report.painted_decor.config -eq $config -and
            $report.painted_decor.frames -eq 8 -and $report.painted_decor.boat.ok -eq $true -and
            $report.painted_decor.reduced_motion_freezes -eq $true -and $report.painted_decor.reduced_motion_gpu_freezes -eq $true -and
            $report.screen_picking.ok -eq $true -and $report.screen_picking.cells -gt 0 -and
            $report.route_identity.ok -eq $true -and $report.route_identity.node_id -eq 'd05_1' -and $report.route_identity.seed -eq 2401
        if($oraclesPassed) {
            $motionCaptures=@($report.painted_decor.captures)
            $missing=@($motionCaptures|Where-Object {-not(Test-Path -LiteralPath $_ -PathType Leaf)})
            $artifactsPresent=$artifactsPresent -and $motionCaptures.Count -eq 8 -and $missing.Count -eq 0
            foreach($region in @('water','channel','vegetation','lantern','stable_ground','stable_wall')) {
                $oraclesPassed=$oraclesPassed -and $report.painted_decor.regions[$region].ok -eq $true -and $report.painted_decor.frozen_regions[$region].ok -eq $true
            }
        }
        if($size -eq '1200x896'){$oraclesPassed=$oraclesPassed -and $report.cross_resolution.ok -eq $true}
        $passed=(Test-DevProcessSuccess $result) -and $artifactsPresent -and $oraclesPassed -and $errors.Count -eq 0
        $results+=@{passed=$passed;resolution=$size;report=$reportPath;errors=$errors;artifacts_present=$artifactsPresent;oracles_passed=$oraclesPassed;process=$result}
        if(-not $passed){throw "Roseaux review failed: $reportPath"}
    }
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$true;room=$room;results=$results;reports=$runRoot}
    Get-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8
} catch {
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$false;room=$room;results=$results;error=$_.Exception.Message;reports=$runRoot}
    Get-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8
    exit 1
} finally {if($lock){$lock.Dispose()}}
