#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Position=0)][ValidateSet('help','doctor','test','capture','inspect','references','context','format','install','configure','selftest')][string]$Command='help',
    [Parameter(Position=1)][string]$Target='',
    [string]$GodotPath='',
    [ValidateSet('1280x720','1200x896','1672x941','1920x1080')][string]$Resolution='1280x720',
    [switch]$Write
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'tools/dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=$null
$engineLock=$null
try {
    if ($Command -eq 'help') {
        Write-Output @'
Dungeon Draft tools (PowerShell 7.2+)
  ./dev.ps1 doctor [-GodotPath PATH]       Environment checks, no import
  ./dev.ps1 test smoke|monsters|terrain|studio|halts|audio|all|test/unit/test_name.gd
  ./dev.ps1 capture inventory|hud [-Resolution 1280x720]
  ./dev.ps1 inspect res://data/spells/example.tres
  ./dev.ps1 references res://data/spells/example.tres
  ./dev.ps1 context keyword               Relevant file paths, no file bodies
  ./dev.ps1 format [file.gd] [-Write]      Check changed scripts by default
  ./dev.ps1 install formatter|workbench|all
  ./dev.ps1 configure workbench           Register the local MCP connection
  ./dev.ps1 selftest                      Harness and strict analyzer tests
Logs and reports: artifacts/dev/<unique-run>/ (never reused as fresh evidence).
'@
        exit 0
    }
    if ($Command -eq 'install') {
        if (-not $Target) { $Target='formatter' }
        & (Join-Path $root 'tools/dev/install.ps1') -Component $Target
        exit 0
    }
    if ($Command -eq 'configure') {
        if($Target -ne 'workbench'){throw 'Configuration target: workbench.'}
        & (Join-Path $root 'tools/dev/configure_workbench.ps1')
        exit 0
    }
    if ($Command -eq 'context') {
        if (-not $Target -or $Target.Length -lt 3) { throw 'Provide a keyword with at least three characters.' }
        $files=@(& git -C $root ls-files --cached --others --exclude-standard)
        if ($LASTEXITCODE -ne 0) { throw 'Git file discovery failed.' }
        $matches=@($files | Where-Object { $_ -match '\.(gd|tscn|tres|md|ps1)$' -and $_ -notmatch '^(artifacts|output|meshy_output)/' -and $_.IndexOf($Target,[StringComparison]::OrdinalIgnoreCase) -ge 0 } | Sort-Object -Unique)
        @{total=$matches.Count;shown=[Math]::Min(30,$matches.Count);truncated=($matches.Count -gt 30);paths=@($matches | Select-Object -First 30)} | ConvertTo-Json -Depth 4
        exit 0
    }
    $runRoot=New-DevRun "$Command-$Target"
    $chain=Get-DevToolchain
    if ($Command -eq 'doctor') {
        $godot=Resolve-DevGodot $GodotPath
        $version=Invoke-DevProcess $godot @('--version') $root $runRoot 'version' 15
        $text=if(Test-Path (Join-Path $runRoot 'version.stdout.log')){[IO.File]::ReadAllText((Join-Path $runRoot 'version.stdout.log')).Trim()}else{''}
        $formatter=Join-Path $root ('artifacts/dev-tools/gdscript-formatter' + $(if($IsWindows){'.exe'}else{''}))
        $gut=(Get-Content (Join-Path $root 'addons/gut/plugin.cfg') -Raw) -match ('version="' + [regex]::Escape($chain.gut_version) + '"')
        $passed=(Test-DevProcessSuccess $version) -and $text -match $chain.godot_version_pattern -and $gut
        $summary=[ordered]@{passed=$passed;godot=$text;godot_path=$godot;gut=$chain.gut_version;gut_matches=$gut;formatter_installed=(Test-Path $formatter);workbench_installed=(Test-Path (Join-Path $root 'artifacts/dev-tools/gaw.exe'));workbench_enabled=([IO.File]::ReadAllText((Join-Path $root 'project.godot')) -match 'enabled=PackedStringArray\([^\r\n]*godot_ai_workbench');import_checked=$false;reports=$runRoot}
        if ($passed -and $GodotPath) { Write-DevJson (Join-Path $root 'artifacts/dev-tools/local.json') @{godot_path=$godot} }
    } elseif ($Command -eq 'format') {
        $formatter=Join-Path $root ('artifacts/dev-tools/gdscript-formatter' + $(if($IsWindows){'.exe'}else{''}))
        if (-not (Test-Path $formatter)) { throw 'Run ./dev.ps1 install formatter first.' }
        $paths=if($Target){@($Target)}else{@(& git -C $root diff --name-only HEAD -- '*.gd'; & git -C $root ls-files --others --exclude-standard -- '*.gd')}
        $paths=@($paths | Where-Object {$_ -notmatch '^(addons|artifacts|output|meshy_output)/' -and (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf)} | Sort-Object -Unique)
        if ($Target -and $paths.Count -eq 0) { throw 'No project GDScript file matched; vendor addons are excluded.' }
        foreach ($path in $paths) {
            $absolute=[IO.Path]::GetFullPath((Join-Path $root $path))
            if (-not $absolute.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($absolute) -ne '.gd') { throw 'Formatting is restricted to project .gd files.' }
        }
        if ($paths.Count -gt 0) {
            $arguments=@('--verify-structure'); if (-not $Write) {$arguments+='--check'}; $arguments+=$paths
            $result=Invoke-DevProcess $formatter $arguments $root $runRoot 'formatter' 120
            $passed=Test-DevProcessSuccess $result
        } else { $passed=$true }
        $summary=@{passed=$passed;checked=$paths.Count;modified=[bool]$Write;files=$paths;reports=$runRoot}
    } elseif ($Command -eq 'selftest') {
        $shell=(Get-Process -Id $PID).Path
        $test=Invoke-DevProcess $shell @('-NoProfile','-File',(Join-Path $root 'tools/dev/test_dev.ps1')) $root $runRoot 'harness' 90
        $strict=Invoke-DevProcess $shell @('-NoProfile','-File',(Join-Path $root 'tools/ci/test_run_gut_strict.ps1')) $root $runRoot 'strict-analyzer' 180
        $passed=(Test-DevProcessSuccess $test) -and (Test-DevProcessSuccess $strict)
        $summary=@{passed=$passed;harness_exit=$test.exit_code;strict_analyzer_exit=$strict.exit_code;reports=$runRoot}
    } else {
        # Commands started through this entry point share one exclusive engine lock.
        $lockPath=Join-Path $root 'artifacts/dev/engine.lock'
        try { $engineLock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) } catch { throw 'Another dev command is using Godot. Retry after it finishes.' }
        $godot=Resolve-DevGodot $GodotPath
        if ($Command -eq 'test') {
            if (-not $Target) {$Target='smoke'}
            $summary=Invoke-DevTests $godot $Target $runRoot
            $passed=$summary.passed
        } elseif ($Command -eq 'capture') {
            if ($Target -notin @('inventory','hud')) { throw 'Capture target: inventory or hud.' }
            $output='res://' + [IO.Path]::GetRelativePath($root,$runRoot).Replace('\','/') + '/captures'
            $arguments=@('--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution',$Resolution,'--log-file',(Join-Path $runRoot 'capture.engine.log'),'res://tools/ui_snapshots/HudGrayboxCaptureRunner.tscn','--',"--output-root=$output","--resolution=$Resolution",'--premium-achilles')
            if ($Target -eq 'inventory') {$arguments+='--state=items'}
            $result=Invoke-DevProcess $godot $arguments $root $runRoot 'capture' 240
            $errors=@(Get-DevEngineErrors $runRoot 'capture' | Sort-Object -Unique)
            $manifest=Join-Path $runRoot 'captures/manifest.json'
            if (-not (Test-Path $manifest)) {throw 'Capture manifest missing; validation incomplete.'}
            $entries=@(Get-Content $manifest -Raw | ConvertFrom-Json)
            $expected=if($Target -eq 'inventory'){1}else{11}
            $missingImages=@($entries | Where-Object {-not(Test-Path -LiteralPath $_.absolute_path -PathType Leaf)})
            $gallery=Join-Path $runRoot 'captures/gallery.html'
            $passed=(Test-DevProcessSuccess $result) -and $errors.Count -eq 0 -and $entries.Count -eq $expected -and @($entries | Where-Object result -ne 'success').Count -eq 0 -and $missingImages.Count -eq 0 -and (Test-Path $gallery)
            $summary=@{passed=$passed;captures=$entries.Count;expected=$expected;missing_images=$missingImages.Count;errors=$errors;gallery=$gallery;reports=$runRoot;visual_review_required=$true}
        } else {
            if ($Target -notmatch '^res://.+\.(tres|tscn)$' -or $Target -match '(^|/)\.\.(/|$)') { throw 'Provide a project res:// resource or scene path.' }
            $reportPath=Join-Path $runRoot 'inspection.json'
            $arguments=@('--headless','--path',$root,'res://tools/dev/InspectResource.tscn','--',"--resource=$Target","--output=$reportPath")
            if($Command -eq 'references'){$arguments+='--references'}
            $result=Invoke-DevProcess $godot $arguments $root $runRoot 'inspection' 90
            $errors=@(Get-DevEngineErrors $runRoot 'inspection' | Sort-Object -Unique)
            if(-not(Test-Path $reportPath)){throw 'Inspection report missing.'}
            $inspection=Get-Content $reportPath -Raw | ConvertFrom-Json
            $passed=(Test-DevProcessSuccess $result) -and $inspection.ok -and $errors.Count -eq 0
            $brief=[ordered]@{resource=$inspection.resource;details=$reportPath}
            if($inspection.PSObject.Properties.Name -contains 'properties'){
                $brief.property_count=@($inspection.properties.PSObject.Properties).Count
                $brief.dependencies=$inspection.dependencies
            }
            if($inspection.PSObject.Properties.Name -contains 'graph'){
                $brief.graph=$inspection.graph
                $brief.usages_count=@($inspection.usages).Count
                $brief.references_count=@($inspection.references).Count
                $brief.scope=$inspection.scope
            }
            if($inspection.PSObject.Properties.Name -contains 'error'){$brief.error=$inspection.error}
            $summary=@{passed=$passed;result=$brief;errors=$errors;reports=$runRoot}
        }
    }
    Write-DevJson (Join-Path $runRoot 'summary.json') $summary
    $summary | ConvertTo-Json -Depth 12
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    if($runRoot){Write-DevJson (Join-Path $runRoot 'summary.json') $summary}
    $summary | ConvertTo-Json
    exit 2
} finally { if($engineLock){$engineLock.Dispose()} }
