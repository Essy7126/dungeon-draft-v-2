#requires -Version 7.2
[CmdletBinding()]
param([ValidateRange(30, 600)][int]$TimeoutSeconds = 180)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root = Get-DevRoot
$runRoot = New-DevRun 'braises-cloitre-review'
$room = 'res://data/rooms/catabase_routes/route_edce0087c741/room.tres'
$results = @()
$lock = $null
try {
    $godot = Resolve-DevGodot ''
    $deadline = [DateTime]::UtcNow.AddSeconds(55)
    while (-not $lock) {
        try { $lock = [IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
        catch [IO.IOException] { if ([DateTime]::UtcNow -ge $deadline) { throw }; Start-Sleep -Milliseconds 500 }
    }
    $relative = 'res://' + [IO.Path]::GetRelativePath($root, $runRoot).Replace('\', '/')
    foreach ($size in @('1920x1080', '1200x896')) {
        $label = "review-$size"
        $userdata = Join-Path $runRoot "userdata-$size"
        [IO.Directory]::CreateDirectory($userdata) | Out-Null
        $environment = @{APPDATA=$userdata; LOCALAPPDATA=$userdata; XDG_DATA_HOME=$userdata}
        $arguments = @(
            '--path', $root, '--single-window', '--rendering-method', 'gl_compatibility',
            '--audio-driver', 'Dummy', '--position', '-3000,-3000',
            '--log-file', (Join-Path $runRoot "$label.engine.log"),
            'res://tools/combat_da_review/Review.tscn', '--', "--room=$room",
            "--capture=$relative/$label.png", "--resolution=$size", '--production-qa', '--braises-cloitre-visual-review'
        )
        if ($size -eq '1200x896') {
            $arguments += "--compare-report=$relative/review-1920x1080.json"
        }
        $result = Invoke-DevProcess $godot $arguments $root $runRoot $label $TimeoutSeconds $environment
        $errors = @(Get-DevEngineErrors $runRoot $label | Sort-Object -Unique)
        $reportPath = Join-Path $runRoot "$label.json"
        $report = if (Test-Path -LiteralPath $reportPath) {
            Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
        } else { $null }
        $artifactsPresent = (Test-Path -LiteralPath (Join-Path $runRoot "$label.png")) -and
            (Test-Path -LiteralPath (Join-Path $runRoot "${label}_after_move_guard.png"))
        $oraclesPassed = $null -ne $report -and $report.ok -eq $true -and
            $report.room -eq $room -and $report.production_qa.ok -eq $true -and
            $report.painted_decor.ok -eq $true -and $report.painted_decor.frames -eq 8 -and
            $report.screen_picking.ok -eq $true -and $report.screen_picking.cells -gt 0
        if ($size -eq '1200x896') {
            $oraclesPassed = $oraclesPassed -and $report.cross_resolution.ok -eq $true
        }
        $passed = (Test-DevProcessSuccess $result) -and $artifactsPresent -and $oraclesPassed -and $errors.Count -eq 0
        $results += @{
            passed=$passed; resolution=$size; report=$reportPath; errors=$errors
            artifacts_present=$artifactsPresent; oracles_passed=$oraclesPassed; process=$result
        }
        if (-not $passed) { throw "Cloister review failed: $reportPath" }
    }
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$true; room=$room; results=$results; reports=$runRoot}
    Get-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8
} catch {
    Write-DevJson (Join-Path $runRoot 'summary.json') @{passed=$false; room=$room; results=$results; error=$_.Exception.Message; reports=$runRoot}
    Get-Content -LiteralPath (Join-Path $runRoot 'summary.json') -Encoding utf8
    exit 1
} finally {
    if ($lock) { $lock.Dispose() }
}


