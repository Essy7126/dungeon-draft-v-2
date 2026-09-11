#requires -Version 7.2
[CmdletBinding()]
param([switch]$Before)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun 'lethe-traces-review'
$godot=Resolve-DevGodot ''
$lock=$null
try {
    $lock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $relative='res://'+[IO.Path]::GetRelativePath($root,$runRoot).Replace('\','/')
    $results=@()
    $sizes=if($Before){@('1920x1080')}else{@('1920x1080','1200x896')}
    foreach($size in $sizes){
        $label="review-$size"
        $environment=@{APPDATA=(Join-Path $runRoot 'userdata');LOCALAPPDATA=(Join-Path $runRoot 'userdata')}
        [IO.Directory]::CreateDirectory($environment.APPDATA)|Out-Null
        $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--log-file',(Join-Path $runRoot "$label.engine.log"),'res://tools/combat_da_review/Review.tscn','--','--room=res://data/rooms/catabase_routes/route_f51a86b714b9/room.tres',"--capture=$relative/$label.png","--resolution=$size")
        if(-not $Before){$arguments+='--production-qa'}
        if(-not $Before -and $size -eq '1920x1080'){$arguments+='--lethe-motion-review'}
        if($size -eq '1200x896'){$arguments+="--compare-report=$relative/review-1920x1080.json"}
        $result=Invoke-DevProcess $godot $arguments $root $runRoot $label 180 $environment
        $errors=@(Get-DevEngineErrors $runRoot $label | Sort-Object -Unique)
        $reportPath=Join-Path $runRoot "$label.json"
        $report=if(Test-Path $reportPath){Get-Content $reportPath -Raw|ConvertFrom-Json}else{$null}
        $passed=(Test-DevProcessSuccess $result) -and $null -ne $report -and $report.ok -and $errors.Count -eq 0
        $results+=@{passed=$passed;report=$reportPath;errors=$errors}
        if(-not $passed){throw "Review failed: $reportPath"}
    }
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$true;results=$results;reports=$runRoot}
    Get-Content (Join-Path $runRoot 'summary.json')
} catch {
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$false;results=$results;error=$_.Exception.Message;reports=$runRoot}
    Get-Content (Join-Path $runRoot 'summary.json')
    exit 1
} finally {if($lock){$lock.Dispose()}}
