param([switch]$Semantic, [switch]$Extension, [switch]$Power)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$scenario = if ($Power) { 'power' } elseif ($Extension) { 'extension' } elseif ($Semantic) { 'semantics' } else { 'persistence' }
$scene = if ($Power) { 'power_probe' } elseif ($Extension) { 'extension_probe' } elseif ($Semantic) { 'semantic_probe' } else { 'combat_probe' }
$outputRoot = Join-Path $projectRoot "artifacts/dev/class_card_vfx/$scenario"
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$godotPath = (Get-Content (Join-Path $projectRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
$engineLock = $null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $engineLock = [IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $env:APPDATA = Join-Path $outputRoot 'appdata'
    $env:LOCALAPPDATA = $env:APPDATA
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    $inputs = @(Get-ChildItem (Join-Path $projectRoot 'vfx/class_cards') -Recurse -File | Where-Object { $_.Extension -in '.gd','.gdshader','.tres' } | ForEach-Object {
        @{ path = [IO.Path]::GetRelativePath($projectRoot, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    })
    foreach ($sourcePath in @('tools/class_card_vfx/combat_probe.gd','tools/class_card_vfx/semantic_probe.gd','tools/class_card_vfx/extension_probe.gd',"tools/class_card_vfx/$scene.gd")) {
        $inputs += @{ path = $sourcePath; sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $sourcePath) -Algorithm SHA256).Hash }
    }
    $contextInputs = @('core/expedition/class_card_catalog.gd','core/expedition/card_ecosystem_catalog.gd','core/expedition/card_ecosystem_effects.gd') | ForEach-Object {
        @{ path = $_; before_sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash }
    }
    $captureStarted = [DateTime]::UtcNow
    & $godotPath --path $projectRoot --resolution 1440x950 --fixed-fps 30 --quit-after 3600 --log-file (Join-Path $outputRoot 'godot.log') "res://tools/class_card_vfx/$scene.tscn"
    if ($LASTEXITCODE -ne 0) { throw 'Combat VFX capture failed.' }
    $reportPath = Join-Path $outputRoot 'report.json'
    if (-not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $captureStarted) { throw 'Missing or stale combat capture report.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if (-not $report.passed -or (Select-String -LiteralPath (Join-Path $outputRoot 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Combat capture has failed checks or engine errors; inspect godot.log.' }
    foreach ($inputFile in $inputs) {
        if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $inputFile.path) -Algorithm SHA256).Hash -ne $inputFile.sha256) { throw "VFX sources changed during capture: $($inputFile.path)" }
    }
    foreach ($contextFile in $contextInputs) {
        $contextFile.after_sha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot $contextFile.path) -Algorithm SHA256).Hash
        $contextFile.changed = $contextFile.before_sha256 -ne $contextFile.after_sha256
    }
    # Other work may update unrelated cards during capture. Record that context;
    # report.casts contains the actual loaded spell contracts used by this run.
    @{ stable_sources = $true; captured_utc = $captureStarted; inputs = $inputs; context_inputs = $contextInputs; scenario = $scenario } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot 'capture_manifest.json') -Encoding utf8
    $report | ConvertTo-Json -Depth 6
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}
