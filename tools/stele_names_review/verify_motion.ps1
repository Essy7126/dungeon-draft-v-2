#requires -Version 7.2
[CmdletBinding()]
param(
    [string]$GodotPath='',
    [ValidateRange(0,60)][int]$WaitForEngineSeconds=55
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../dev/DevTools.psm1') -Force -DisableNameChecking
$root=Get-DevRoot
$runRoot=New-DevRun 'stele-names-motion'
$engineLock=$null

function New-MotionContactSheet([object]$Sequence,[object]$Region,[string]$Directory) {
    # Technical crops only: preserve GPU pixels with nearest-neighbour enlargement.
    $rect=$Region.rect
    $scale=[Math]::Min(2.0,220.0/[Math]::Max([double]$rect[2],[double]$rect[3]))
    $cropWidth=[Math]::Max(1,[int]([double]$rect[2]*$scale))
    $cropHeight=[Math]::Max(1,[int]([double]$rect[3]*$scale))
    $cellWidth=[Math]::Max(165,$cropWidth+18)
    $cellHeight=$cropHeight+38
    $rows=[int][Math]::Ceiling($Sequence.frames.Count/4.0)
    $bitmap=[System.Drawing.Bitmap]::new($cellWidth*4,64+$cellHeight*$rows)
    $graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $font=[System.Drawing.Font]::new('Segoe UI',11)
    $titleFont=[System.Drawing.Font]::new('Segoe UI',13,[System.Drawing.FontStyle]::Bold)
    $brush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(227,235,237))
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(18,28,33))
        $graphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.DrawString("$($Region.id) | $($Sequence.mode) | $($Sequence.resolution)",$titleFont,$brush,12,8)
        $graphics.DrawString("$($Sequence.layer) only | source GPU crop | enlargement $([Math]::Round($scale,2))x",$font,$brush,12,34)
        for($index=0;$index -lt $Sequence.frames.Count;$index++) {
            $frame=$Sequence.frames[$index]
            $column=$index%4
            $row=[int][Math]::Floor($index/4.0)
            $x=$column*$cellWidth+9
            $y=64+$row*$cellHeight
            $graphics.DrawString(('t = {0:0.00} s' -f [double]$frame.time),$font,$brush,$x,$y)
            $source=[System.Drawing.Image]::FromFile([string]$frame.path)
            try {
                $destination=[System.Drawing.Rectangle]::new($x,$y+24,$cropWidth,$cropHeight)
                $sourceRect=[System.Drawing.Rectangle]::new([int]$rect[0],[int]$rect[1],[int]$rect[2],[int]$rect[3])
                $graphics.DrawImage($source,$destination,$sourceRect,[System.Drawing.GraphicsUnit]::Pixel)
            } finally {$source.Dispose()}
        }
        $name="$($Sequence.resolution)_$($Sequence.layer)_$($Sequence.mode)_$($Region.id)_contact.png"
        $path=Join-Path $Directory $name
        $bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)
        return $path
    } finally {
        $brush.Dispose(); $titleFont.Dispose(); $font.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
}

try {
    $godot=Resolve-DevGodot $GodotPath
    $deadline=[DateTime]::UtcNow.AddSeconds($WaitForEngineSeconds)
    while(-not $engineLock) {
        try {$engineLock=[IO.File]::Open((Join-Path $root 'artifacts/dev/engine.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
        catch [IO.IOException] {if([DateTime]::UtcNow -ge $deadline){throw}; Start-Sleep -Milliseconds 500}
    }
    $userdata=Join-Path $runRoot 'userdata'
    [IO.Directory]::CreateDirectory($userdata) | Out-Null
    $environment=@{APPDATA=$userdata;LOCALAPPDATA=$userdata}
    $version=Invoke-DevProcess $godot @('--version') $root $runRoot 'version' 15 $environment
    $versionText=[IO.File]::ReadAllText((Join-Path $runRoot 'version.stdout.log')).Trim()
    if(-not(Test-DevProcessSuccess $version) -or $versionText -notmatch (Get-DevToolchain).godot_version_pattern){throw 'Godot version mismatch'}
    $import=Invoke-DevProcess $godot @('--headless','--editor','--recovery-mode','--path',$root,'--log-file',(Join-Path $runRoot 'import.engine.log'),'--import') $root $runRoot 'import' 240 $environment
    $importErrors=@(Get-DevEngineErrors $runRoot 'import' | Sort-Object -Unique)
    if(-not(Test-DevProcessSuccess $import) -or $importErrors.Count -gt 0){throw "Import failed: $($importErrors -join ' | ')"}
    $scene='res://tools/stele_names_review/VerifySteleMotion.tscn'
    $compile=Invoke-DevProcess $godot @('--headless','--path',$root,'--log-file',(Join-Path $runRoot 'compile.engine.log'),$scene,'--','--compile-probe') $root $runRoot 'compile' 60 $environment
    $compileErrors=@(Get-DevEngineErrors $runRoot 'compile' | Sort-Object -Unique)
    $compileOutput=Get-Content -LiteralPath (Join-Path $runRoot 'compile.stdout.log') -Raw
    if(-not(Test-DevProcessSuccess $compile) -or $compileErrors.Count -gt 0 -or $compileOutput -notmatch '(?m)^HALT_VERIFIER_COMPILED\r?$'){throw "Motion verifier failed compilation: $($compileErrors -join ' | ')"}
    $arguments=@('--verbose','--single-window','--path',$root,'--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--resolution','1280x720','--log-file',(Join-Path $runRoot 'motion.engine.log'),$scene,'--',"--output-root=$runRoot")
    $result=Invoke-DevProcess $godot $arguments $root $runRoot 'motion' 420 $environment
    $errors=@(Get-DevEngineErrors $runRoot 'motion' | Sort-Object -Unique)
    $reportPath=Join-Path $runRoot 'motion_verification.json'
    if(-not(Test-Path -LiteralPath $reportPath)){throw 'Missing GPU report: validation incomplete.'}
    $report=Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json
    $missingCaptures=@($report.captures | Where-Object {-not(Test-Path -LiteralPath $_ -PathType Leaf)})
    $sheets=@()
    if($missingCaptures.Count -eq 0) {
        Add-Type -AssemblyName System.Drawing
        foreach($sequence in $report.sequences) {
            foreach($region in $sequence.regions) {
                $sheets+=New-MotionContactSheet $sequence $region $runRoot
            }
        }
    }
    Write-DevJson (Join-Path $runRoot 'contact_sheets.json') @{sheets=$sheets;times=$report.times;manual_visual_review_required=$true}
    $passed=(Test-DevProcessSuccess $result) -and $report.passed -and $report.rendered -and $report.check_count -gt 0 -and $report.sequences.Count -eq 8 -and $report.captures.Count -ge 72 -and $sheets.Count -eq 60 -and $missingCaptures.Count -eq 0 -and $errors.Count -eq 0
    $summary=@{passed=$passed;checks=$report.check_count;captures=$report.captures.Count;contact_sheets=$sheets.Count;errors=$errors;missing_captures=$missingCaptures;manual_visual_review_required=$true;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'motion_summary.json') $summary
    $summary | ConvertTo-Json -Depth 6
    exit $(if($passed){0}else{1})
} catch {
    $summary=@{passed=$false;error=$_.Exception.Message;reports=$runRoot}
    Write-DevJson (Join-Path $runRoot 'motion_summary.json') $summary
    $summary | ConvertTo-Json
    exit 1
} finally {if($engineLock){$engineLock.Dispose()}}
