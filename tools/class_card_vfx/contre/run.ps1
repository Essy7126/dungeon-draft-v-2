param([switch]$Capture, [switch]$Workshop)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$outputRoot = Join-Path $projectRoot 'artifacts/dev/class_card_vfx/contre/combat'
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null
$godotPath = (Get-Content (Join-Path $projectRoot 'artifacts/dev-tools/local.json') -Raw | ConvertFrom-Json).godot_path
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$engineLock = $null
try {
    if ($Capture -or $Workshop) {
        $lockWait = [Diagnostics.Stopwatch]::StartNew()
        while ($null -eq $engineLock) {
            try {
                $engineLock = [IO.File]::Open((Join-Path $projectRoot 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            } catch [IO.IOException] {
                if ($lockWait.Elapsed.TotalSeconds -ge 1200) { throw 'Godot is still in use by another validation after twenty minutes.' }
                Start-Sleep -Seconds 1
            }
        }
    }
    $env:APPDATA = Join-Path $projectRoot ('artifacts/dev/contre-userdata/' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $env:LOCALAPPDATA = $env:APPDATA
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    if ($Workshop) {
        & $godotPath --headless --path $projectRoot --script 'res://tools/class_card_vfx/contre/export_workshop.gd' *> (Join-Path $outputRoot 'workshop.log')
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $outputRoot 'workshop.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Studio clip export failed; inspect workshop.log.' }
    } elseif ($Capture) {
        $sourcePaths = @(
            'battle/battle.gd', 'battle/audio/catabase_battle_audio.gd', 'core/audio/feedback_cues.gd',
            'battle/floating_text.gd', 'battle/combat_feedback/combat_feedback_settings.gd', 'battle/combat_feedback/combat_feedback_settings.tres',
            'vfx/class_cards/class_card_vfx_router.gd', 'core/expedition/class_card_catalog.gd',
            'core/expedition/consumable_card_modifier.gd', 'core/expedition/consumable_card_spells.gd', 'core/expedition/consumable_card_effects.gd', 'core/expedition/consumable_card_turns.gd', 'core/expedition/consumable_card_terrain.gd', 'data/cards/consumable_v2/catalog.json', 'core/expedition/class_card_vfx_facts.gd', 'characters/achilles/2d/passe_rive_card_bindings.gd', 'vfx/class_cards/sentence/presentation.gd', 'tools/class_card_vfx/combat_probe.gd',
            'tools/class_card_vfx/semantic_probe.gd', 'tools/class_card_vfx/orage/review.gd', 'tools/class_card_vfx/contre/review.gd'
        )
        $sourcePaths += @(Get-ChildItem (Join-Path $projectRoot 'vfx/class_cards/contre') -File | Where-Object { $_.Extension -in '.gd','.gdshader','.png','.wav','.json' } | ForEach-Object { [IO.Path]::GetRelativePath($projectRoot, $_.FullName) })
        $sourcePaths += @(Get-ChildItem (Join-Path $projectRoot 'ui/expedition') -File -Filter '*.gd' | ForEach-Object { [IO.Path]::GetRelativePath($projectRoot, $_.FullName) })
        $inputs = @($sourcePaths | ForEach-Object { @{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $_) -Algorithm SHA256).Hash} })
        $started = [DateTime]::UtcNow
        & $godotPath --path $projectRoot --audio-driver Dummy --position=-3000,-3000 --resolution 1440x950 --fixed-fps 30 --max-fps 60 --quit-after 18000 --log-file (Join-Path $outputRoot 'godot.log') 'res://tools/class_card_vfx/contre/review.tscn' -- --capture-contre *> (Join-Path $outputRoot 'console.log')
        $captureExitCode = $LASTEXITCODE
        @{started_utc=$started.ToString('o');finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$captureExitCode} | ConvertTo-Json | Set-Content (Join-Path $outputRoot 'capture_process.json')
        $reportPath = Join-Path $outputRoot 'report.json'
        if ($captureExitCode -ne 0 -or -not (Test-Path -LiteralPath $reportPath) -or (Get-Item -LiteralPath $reportPath).LastWriteTimeUtc -lt $started) { throw "Missing completed comparison report (engine exit $captureExitCode)." }
        $report = Get-Content $reportPath -Raw | ConvertFrom-Json
        if (-not $report.passed -or $report.frames -ne 180 -or (Select-String -LiteralPath (Join-Path $outputRoot 'godot.log') -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'Comparison failed. Inspect report.json and godot.log.' }
        foreach ($source in $inputs) {
            if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $source.path) -Algorithm SHA256).Hash -ne $source.sha256) { throw "Source changed during comparison: $($source.path)" }
        }
        @{captured_utc=$started.ToString('o');stable_selected_sources=$true;inputs=$inputs} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $outputRoot 'capture_manifest.json')
        @{passed=$report.passed;frames=$report.frames;checks=$report.checks.Count;report=$reportPath} | ConvertTo-Json
    } else {
        & $godotPath --path $projectRoot --resolution 1440x950 --log-file (Join-Path $outputRoot 'interactive.log') 'res://tools/class_card_vfx/contre/review.tscn'
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -ne $engineLock) { $engineLock.Dispose() }
}



