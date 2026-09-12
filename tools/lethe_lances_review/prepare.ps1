#requires -Version 7.2
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root = Get-DevRoot
$run = New-DevRun 'lethe-lances-prepare'
$lock = $null
try {
    $lock = [IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $godot = Resolve-DevGodot ''
    $userdata = Join-Path $run 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment = @{APPDATA=$userdata; LOCALAPPDATA=$userdata; XDG_DATA_HOME=$userdata}
    $version = Invoke-DevProcess $godot @('--version') $root $run 'version' 15
    $versionText = [IO.File]::ReadAllText((Join-Path $run 'version.stdout.log')).Trim()
    if (-not (Test-DevProcessSuccess $version) -or $versionText -notmatch (Get-DevToolchain).godot_version_pattern) { throw 'Godot version mismatch' }
    $import = Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $run 'import.engine.log'),'--import') $root $run 'import' 240 $environment
    $errors = @(Get-DevEngineErrors $run 'import' | Sort-Object -Unique)
    if (-not (Test-DevProcessSuccess $import) -or $errors.Count -gt 0) { throw "Import failed: $($errors -join ' | ')" }
    $prepare = Invoke-DevProcess $godot @('--headless','--path',$root,'--log-file',(Join-Path $run 'prepare.engine.log'),'res://tools/lethe_lances_review/PrepareRoom.tscn') $root $run 'prepare' 90 $environment
    $errors = @(Get-DevEngineErrors $run 'prepare' | Sort-Object -Unique)
    $text = [IO.File]::ReadAllText((Join-Path $run 'prepare.stdout.log'))
    if (-not (Test-DevProcessSuccess $prepare) -or $errors.Count -gt 0 -or $text -notmatch 'LETHE_LANCES_PREPARED:.*"ok":true') { throw "Preparation failed: $($errors -join ' | ')" }
    Write-DevJson (Join-Path $run 'summary.json') @{passed=$true; reports=$run; import=$import; prepare=$prepare}
    Get-Content (Join-Path $run 'summary.json') -Encoding utf8
} catch {
    Write-DevJson (Join-Path $run 'summary.json') @{passed=$false; reports=$run; error=$_.Exception.Message}
    Get-Content (Join-Path $run 'summary.json') -Encoding utf8
    exit 1
} finally { if ($lock) { $lock.Dispose() } }
