#requires -Version 7.2
[CmdletBinding()]
param([string]$GodotPath='', [switch]$PreviewsOnly, [switch]$BrowserOnly, [switch]$RouteVariants, [switch]$Seuil)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun 'run-explorer-verify'
$engineLock=$null
try {
    $godot=Resolve-DevGodot $GodotPath
    $engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $relative='res://' + [IO.Path]::GetRelativePath($root,$runRoot).Replace('\','/')
    $environment=@{APPDATA=(Join-Path $runRoot 'userdata'); LOCALAPPDATA=(Join-Path $runRoot 'userdata')}
    [IO.Directory]::CreateDirectory($environment.APPDATA) | Out-Null
    $results=@()
    if(-not $PreviewsOnly) {
        $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--log-file',(Join-Path $runRoot 'browser.engine.log'),'res://tools/run_explorer/VerifyRunExplorer.tscn','--',"--output=$relative")
        $result=Invoke-DevProcess $godot $arguments $root $runRoot 'browser' 240 $environment
        $errors=@(Get-DevEngineErrors $runRoot 'browser' | Sort-Object -Unique)
        $reportPath=Join-Path $runRoot 'verification.json'
        $report=if(Test-Path $reportPath){Get-Content $reportPath -Raw | ConvertFrom-Json}else{$null}
        $passed=(Test-DevProcessSuccess $result) -and $null -ne $report -and $report.passed -and $report.count -gt 0 -and $errors.Count -eq 0
        $results+=@{kind='browser';passed=$passed;errors=$errors;report=$reportPath}
        if(-not $passed){throw "Explorer browser checks failed: $($errors -join ' | ')"}
    }
    $cases=if($BrowserOnly){@()}else{@(@('d01_0','play'),@('d20_0','play'),@('d04_1','play'),@('d08_0','play'),@('d08_1','play'),@('d08_secret','play'),@('d18_0','art'),@('entry','play'))}
    if($RouteVariants){$cases=@(@('d02_0','play'),@('d02_1','play'),@('d03_0','art'),@('d03_1','art'),@('d18_0','play'))}
    if($Seuil){$cases=@(,@('d01_0','aftermath'))}
    foreach($case in $cases) {
        $label=$case[0]+'-'+$case[1]
        $caseRoot=Join-Path $runRoot $label
        [IO.Directory]::CreateDirectory((Join-Path $caseRoot 'userdata')) | Out-Null
        $caseRelative=$relative+'/'+$label
        $caseEnvironment=@{APPDATA=(Join-Path $caseRoot 'userdata');LOCALAPPDATA=(Join-Path $caseRoot 'userdata')}
        $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--resolution','1280x720','--position','-3000,-3000','--log-file',(Join-Path $caseRoot 'preview.engine.log'),'res://tools/run_explorer/RunExplorerPreview.tscn','--',"--explorer-output=$caseRelative",'--explorer-seed=2401',"--explorer-node=$($case[0])","--explorer-mode=$($case[1])",'--explorer-capture')
        $result=Invoke-DevProcess $godot $arguments $root $caseRoot 'preview' 120 $caseEnvironment
        $errors=@(Get-DevEngineErrors $caseRoot 'preview' | Sort-Object -Unique)
        $reportPath=Join-Path $caseRoot 'preview.json'
        $report=if(Test-Path $reportPath){Get-Content $reportPath -Raw | ConvertFrom-Json}else{$null}
        $captures=@(Get-ChildItem -LiteralPath $caseRoot -Filter 'capture-*.png')
        $passed=(Test-DevProcessSuccess $result) -and $null -ne $report -and $report.PSObject.Properties.Name.Contains('ready') -and $report.ready -and $captures.Count -gt 0 -and $errors.Count -eq 0
        $results+=@{kind=$label;passed=$passed;errors=$errors;report=$reportPath}
        if(-not $passed){throw "Preview $label failed: $($errors -join ' | ')"}
    }
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$true;results=$results;reports=$runRoot}
    Get-Content (Join-Path $runRoot 'summary.json')
} catch {
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$false;error=$_.Exception.Message;results=$results;reports=$runRoot}
    Get-Content (Join-Path $runRoot 'summary.json')
    exit 1
} finally {
    if($engineLock){$engineLock.Dispose()}
}
