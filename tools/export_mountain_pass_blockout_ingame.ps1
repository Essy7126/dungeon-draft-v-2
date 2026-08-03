param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$CanvasSize = 2048
$LogicalSize = 14
$SceneBounds = [Drawing.RectangleF]::FromLTRB(184, 360, 1864, 1660)
$ExpectedRows = @(
    'XXXX......XXXX'
    'XX..........XX'
    'X.......EEE..X'
    '........EEE...'
    '.........RR...'
    '....#....RR...'
    '..##..........'
    '......~~~.....'
    'XX...~~~~#....'
    'XX..A.~...#...'
    '...AAA..##....'
    'X..AA........X'
    'XX..........XX'
    'XXXX......XXXX'
)

$SourcePath = Join-Path $ProjectRoot 'data\maps\mountain_pass_blockout.tres'
$OutputDirectory = Join-Path $ProjectRoot 'artifacts\maps\mountain_pass_blockout'
$OldReferencePath = Join-Path $OutputDirectory 'mountain_pass_blockout_reference.png'
$Source = Get-Content -Raw -LiteralPath $SourcePath
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory

function Get-MatchedValue {
    param([string]$Pattern)

    $match = [regex]::Match($Source, $Pattern)
    if (-not $match.Success) {
        throw "Missing required data in $SourcePath (pattern: $Pattern)"
    }
    return $match.Groups[1].Value
}

function Get-Vector2 {
    param([string]$Name)

    $match = [regex]::Match($Source, "$Name\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)")
    if (-not $match.Success) {
        throw "Missing Vector2 '$Name' in $SourcePath"
    }
    return @([single]$match.Groups[1].Value, [single]$match.Groups[2].Value)
}

$LayoutText = Get-MatchedValue 'layout_rows\s*=\s*PackedStringArray\(([^\r\n]+)\)'
$Rows = @([regex]::Matches($LayoutText, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$Origin = Get-Vector2 'grid_origin'
$AxisX = Get-Vector2 'axis_x'
$AxisY = Get-Vector2 'axis_y'
$CliffDepth = [single](Get-MatchedValue 'cliff_depth\s*=\s*([\d.]+)')
$ObstacleHeight = [single](Get-MatchedValue 'obstacle_height\s*=\s*([\d.]+)')
$LandmarkHeight = [single](Get-MatchedValue 'landmark_height\s*=\s*([\d.]+)')

$RoadCells = [Collections.Generic.HashSet[string]]::new()
$RoadText = Get-MatchedValue 'road_visual_cells\s*=\s*Array\[Vector2i\]\(([^\r\n]+)\)'
foreach ($match in [regex]::Matches($RoadText, 'Vector2i\((\d+),\s*(\d+)\)')) {
    $null = $RoadCells.Add("$($match.Groups[1].Value),$($match.Groups[2].Value)")
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Label)

    if ($Actual -ne $Expected) {
        throw "Validation failed for ${Label}: expected '$Expected', got '$Actual'"
    }
}

Assert-Equal $Rows.Count 14 'layout row count'
for ($rowIndex = 0; $rowIndex -lt $ExpectedRows.Count; $rowIndex++) {
    Assert-Equal $Rows[$rowIndex] $ExpectedRows[$rowIndex] "layout row $rowIndex"
}
Assert-Equal $Origin[0] 1024 'grid origin x'
Assert-Equal $Origin[1] 650 'grid origin y'
Assert-Equal $AxisX[0] 48 'axis_x x'
Assert-Equal $AxisX[1] 24 'axis_x y'
Assert-Equal $AxisY[0] -48 'axis_y x'
Assert-Equal $AxisY[1] 24 'axis_y y'
Assert-Equal $CliffDepth 58 'cliff depth'
Assert-Equal $ObstacleHeight 34 'obstacle height'
Assert-Equal $LandmarkHeight 50 'landmark height'
Assert-Equal $RoadCells.Count 34 'road visual cell count'

$SymbolCounts = @{}
foreach ($symbol in @('.', '~', '#', 'R', 'X', 'A', 'E')) {
    $SymbolCounts[$symbol] = 0
}
foreach ($row in $Rows) {
    Assert-Equal $row.Length 14 'layout column count'
    foreach ($character in $row.ToCharArray()) {
        $SymbolCounts[[string]$character]++
    }
}
Assert-Equal $SymbolCounts['.'] 133 'normal cell count'
Assert-Equal $SymbolCounts['~'] 8 'ice cell count'
Assert-Equal $SymbolCounts['#'] 7 'obstacle cell count'
Assert-Equal $SymbolCounts['R'] 4 'ruin cell count'
Assert-Equal $SymbolCounts['X'] 32 'void cell count'
Assert-Equal $SymbolCounts['A'] 6 'zone A cell count'
Assert-Equal $SymbolCounts['E'] 6 'zone E cell count'

function New-Color {
    param([string]$Hex, [int]$Alpha = 255)

    $value = $Hex.TrimStart('#')
    return [Drawing.Color]::FromArgb(
        $Alpha,
        [Convert]::ToInt32($value.Substring(0, 2), 16),
        [Convert]::ToInt32($value.Substring(2, 2), 16),
        [Convert]::ToInt32($value.Substring(4, 2), 16)
    )
}

function New-Point {
    param([single]$X, [single]$Y)

    return [Drawing.PointF]::new($X, $Y)
}

function Get-Symbol {
    param([int]$X, [int]$Y)

    if ($X -lt 0 -or $X -ge $LogicalSize -or $Y -lt 0 -or $Y -ge $LogicalSize) {
        return 'X'
    }
    return $Rows[$Y].Substring($X, 1)
}

function Get-CellCenter {
    param([int]$X, [int]$Y)

    return New-Point `
        ($Origin[0] + $X * $AxisX[0] + $Y * $AxisY[0]) `
        ($Origin[1] + $X * $AxisX[1] + $Y * $AxisY[1])
}

function Get-Diamond {
    param([int]$X, [int]$Y)

    $center = Get-CellCenter $X $Y
    return [Drawing.PointF[]]@(
        (New-Point $center.X ($center.Y - 24))
        (New-Point ($center.X + 48) $center.Y)
        (New-Point $center.X ($center.Y + 24))
        (New-Point ($center.X - 48) $center.Y)
    )
}

function Fill-Polygon {
    param($Graphics, [Drawing.PointF[]]$Points, [Drawing.Color]$Color)

    $brush = [Drawing.SolidBrush]::new($Color)
    try {
        $Graphics.FillPolygon($brush, $Points)
    } finally {
        $brush.Dispose()
    }
}

function Stroke-Polygon {
    param($Graphics, [Drawing.PointF[]]$Points, [Drawing.Color]$Color, [single]$Width = 1)

    $pen = [Drawing.Pen]::new($Color, $Width)
    $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    try {
        $Graphics.DrawPolygon($pen, $Points)
    } finally {
        $pen.Dispose()
    }
}

function Fill-Rectangle {
    param($Graphics, [single]$X, [single]$Y, [single]$Width, [single]$Height, [Drawing.Color]$Color)

    $brush = [Drawing.SolidBrush]::new($Color)
    try {
        $Graphics.FillRectangle($brush, $X, $Y, $Width, $Height)
    } finally {
        $brush.Dispose()
    }
}

function Get-WalkableCells {
    $result = [Collections.Generic.List[object]]::new()
    for ($y = 0; $y -lt $LogicalSize; $y++) {
        for ($x = 0; $x -lt $LogicalSize; $x++) {
            if ((Get-Symbol $x $y) -ne 'X') {
                $center = Get-CellCenter $x $y
                $result.Add([pscustomobject]@{ X = $x; Y = $y; Center = $center })
            }
        }
    }
    return @($result | Sort-Object { $_.Center.Y }, { $_.Center.X })
}

function Get-ExposedEdges {
    $directions = @(
        @{ Name = 'U'; X = 0; Y = -1; A = 0; B = 1 }
        @{ Name = 'R'; X = 1; Y = 0; A = 1; B = 2 }
        @{ Name = 'D'; X = 0; Y = 1; A = 2; B = 3 }
        @{ Name = 'L'; X = -1; Y = 0; A = 3; B = 0 }
    )
    $result = [Collections.Generic.List[object]]::new()
    foreach ($cell in (Get-WalkableCells)) {
        $diamond = Get-Diamond $cell.X $cell.Y
        foreach ($direction in $directions) {
            if ((Get-Symbol ($cell.X + $direction.X) ($cell.Y + $direction.Y)) -eq 'X') {
                $a = $diamond[$direction.A]
                $b = $diamond[$direction.B]
                $result.Add([pscustomobject]@{
                    Name = $direction.Name
                    A = $a
                    B = $b
                    Depth = (($a.Y + $b.Y) * 0.5)
                })
            }
        }
    }
    return @($result | Sort-Object Depth)
}

function Get-CellGroups {
    param([string]$Target)

    $remaining = [Collections.Generic.HashSet[string]]::new()
    for ($y = 0; $y -lt $LogicalSize; $y++) {
        for ($x = 0; $x -lt $LogicalSize; $x++) {
            if ((Get-Symbol $x $y) -eq $Target) {
                $null = $remaining.Add("$x,$y")
            }
        }
    }

    $groups = [Collections.Generic.List[object]]::new()
    while ($remaining.Count -gt 0) {
        $queue = [Collections.Generic.Queue[string]]::new()
        $group = [Collections.Generic.List[object]]::new()
        $seed = @($remaining)[0]
        $queue.Enqueue($seed)
        $null = $remaining.Remove($seed)

        while ($queue.Count -gt 0) {
            $parts = $queue.Dequeue().Split(',')
            $x = [int]$parts[0]
            $y = [int]$parts[1]
            $group.Add([pscustomobject]@{ X = $x; Y = $y })
            foreach ($offset in @(@(0, -1), @(1, 0), @(0, 1), @(-1, 0))) {
                $key = "$($x + $offset[0]),$($y + $offset[1])"
                if ($remaining.Remove($key)) {
                    $queue.Enqueue($key)
                }
            }
        }
        $groups.Add(@($group))
    }
    return @($groups)
}

function Get-ConvexHull {
    param([Drawing.PointF[]]$InputPoints)

    $unique = @{}
    foreach ($point in $InputPoints) {
        $unique["$($point.X),$($point.Y)"] = $point
    }
    $points = @($unique.Values | Sort-Object X, Y)

    function Get-CrossProduct($OriginPoint, $PointA, $PointB) {
        return (($PointA.X - $OriginPoint.X) * ($PointB.Y - $OriginPoint.Y)) -
            (($PointA.Y - $OriginPoint.Y) * ($PointB.X - $OriginPoint.X))
    }

    $lower = [Collections.Generic.List[Drawing.PointF]]::new()
    foreach ($point in $points) {
        while ($lower.Count -ge 2 -and
            (Get-CrossProduct $lower[$lower.Count - 2] $lower[$lower.Count - 1] $point) -le 0) {
            $lower.RemoveAt($lower.Count - 1)
        }
        $lower.Add($point)
    }

    $upper = [Collections.Generic.List[Drawing.PointF]]::new()
    for ($index = $points.Count - 1; $index -ge 0; $index--) {
        $point = $points[$index]
        while ($upper.Count -ge 2 -and
            (Get-CrossProduct $upper[$upper.Count - 2] $upper[$upper.Count - 1] $point) -le 0) {
            $upper.RemoveAt($upper.Count - 1)
        }
        $upper.Add($point)
    }

    $lower.RemoveAt($lower.Count - 1)
    $upper.RemoveAt($upper.Count - 1)
    return [Drawing.PointF[]]@($lower.ToArray() + $upper.ToArray())
}

function Draw-ContinuousEnvironment {
    param($Graphics)

    # One authored topography envelope. Every subdivision below overlaps this mass,
    # so the exterior reads as one connected scene rather than detached assets.
    $envelope = [Drawing.PointF[]]@(
        (New-Point 184 620)
        (New-Point 350 500)
        (New-Point 560 400)
        (New-Point 780 430)
        (New-Point 1024 360)
        (New-Point 1280 450)
        (New-Point 1480 420)
        (New-Point 1690 500)
        (New-Point 1864 620)
        (New-Point 1864 1370)
        (New-Point 1718 1520)
        (New-Point 1528 1610)
        (New-Point 1024 1660)
        (New-Point 520 1610)
        (New-Point 330 1520)
        (New-Point 184 1370)
    )
    Fill-Polygon $Graphics $envelope (New-Color '929BA2')

    $rearMass = [Drawing.PointF[]]@(
        (New-Point 184 620)
        (New-Point 350 500)
        (New-Point 560 400)
        (New-Point 780 430)
        (New-Point 1024 360)
        (New-Point 1280 450)
        (New-Point 1480 420)
        (New-Point 1690 500)
        (New-Point 1864 620)
        (New-Point 1740 720)
        (New-Point 1490 770)
        (New-Point 1280 735)
        (New-Point 1024 790)
        (New-Point 770 740)
        (New-Point 540 775)
        (New-Point 305 720)
    )
    Fill-Polygon $Graphics $rearMass (New-Color 'A8B0B5')

    $rearBreak = [Drawing.PointF[]]@(
        (New-Point 305 720)
        (New-Point 540 775)
        (New-Point 770 740)
        (New-Point 1024 790)
        (New-Point 1280 735)
        (New-Point 1490 770)
        (New-Point 1740 720)
        (New-Point 1660 825)
        (New-Point 1440 855)
        (New-Point 1220 825)
        (New-Point 1024 865)
        (New-Point 820 825)
        (New-Point 610 855)
        (New-Point 390 820)
    )
    Fill-Polygon $Graphics $rearBreak (New-Color '808A91')

    $leftShoulder = [Drawing.PointF[]]@(
        (New-Point 184 620)
        (New-Point 390 820)
        (New-Point 560 900)
        (New-Point 520 1120)
        (New-Point 650 1290)
        (New-Point 520 1610)
        (New-Point 330 1520)
        (New-Point 184 1370)
    )
    Fill-Polygon $Graphics $leftShoulder (New-Color '7D878E')

    $rightShoulder = [Drawing.PointF[]]@(
        (New-Point 1864 620)
        (New-Point 1660 825)
        (New-Point 1490 910)
        (New-Point 1530 1120)
        (New-Point 1400 1290)
        (New-Point 1528 1610)
        (New-Point 1718 1520)
        (New-Point 1864 1370)
    )
    Fill-Polygon $Graphics $rightShoulder (New-Color '778188')

    $frontMass = [Drawing.PointF[]]@(
        (New-Point 520 1120)
        (New-Point 650 1290)
        (New-Point 850 1375)
        (New-Point 1024 1435)
        (New-Point 1198 1375)
        (New-Point 1400 1290)
        (New-Point 1530 1120)
        (New-Point 1528 1610)
        (New-Point 1024 1660)
        (New-Point 520 1610)
    )
    Fill-Polygon $Graphics $frontMass (New-Color '3B4248')

    $frontPlane = [Drawing.PointF[]]@(
        (New-Point 650 1290)
        (New-Point 850 1375)
        (New-Point 1024 1435)
        (New-Point 1198 1375)
        (New-Point 1400 1290)
        (New-Point 1320 1475)
        (New-Point 1024 1540)
        (New-Point 728 1475)
    )
    Fill-Polygon $Graphics $frontPlane (New-Color '535C62')
}

function Draw-ExposedCliffs {
    param($Graphics)

    foreach ($edge in (Get-ExposedEdges)) {
        $face = [Drawing.PointF[]]@(
            $edge.A
            $edge.B
            (New-Point $edge.B.X ($edge.B.Y + $CliffDepth))
            (New-Point $edge.A.X ($edge.A.Y + $CliffDepth))
        )
        $color = if ($edge.Name -in @('R', 'D')) {
            New-Color '30363B'
        } else {
            New-Color '3B4248'
        }
        Fill-Polygon $Graphics $face $color
        Stroke-Polygon $Graphics $face (New-Color '22282D' 170) 1
    }
}

function Draw-Ground {
    param($Graphics, [bool]$ShowGrid)

    foreach ($cell in (Get-WalkableCells)) {
        $symbol = Get-Symbol $cell.X $cell.Y
        $key = "$($cell.X),$($cell.Y)"
        $color = if ($symbol -eq '~') {
            New-Color 'B6DCEB'
        } elseif ($RoadCells.Contains($key)) {
            New-Color 'CAC3B7'
        } else {
            New-Color 'EFF2F3'
        }
        $diamond = Get-Diamond $cell.X $cell.Y
        Fill-Polygon $Graphics $diamond $color

        if ($symbol -eq 'A') {
            Fill-Polygon $Graphics $diamond (New-Color '3C91DD' 50)
        } elseif ($symbol -eq 'E') {
            Fill-Polygon $Graphics $diamond (New-Color 'D75B52' 50)
        }

        if ($ShowGrid) {
            Stroke-Polygon $Graphics $diamond (New-Color '31434F' 150) 1.25
        }
    }
}

function Draw-Obstacles {
    param($Graphics)

    $entries = [Collections.Generic.List[object]]::new()
    foreach ($group in @((Get-CellGroups '#') + (Get-CellGroups 'R'))) {
        $depth = -1
        foreach ($cell in $group) {
            $depth = [Math]::Max($depth, (Get-CellCenter $cell.X $cell.Y).Y)
        }
        $entries.Add([pscustomobject]@{ Group = $group; Depth = $depth })
    }

    foreach ($entry in @($entries | Sort-Object Depth)) {
        $points = [Collections.Generic.List[Drawing.PointF]]::new()
        foreach ($cell in $entry.Group) {
            $points.AddRange([Drawing.PointF[]](Get-Diamond $cell.X $cell.Y))
        }
        $base = Get-ConvexHull ([Drawing.PointF[]]$points.ToArray())
        $isRuin = (Get-Symbol $entry.Group[0].X $entry.Group[0].Y) -eq 'R'
        $height = if ($isRuin) { $LandmarkHeight } else { $ObstacleHeight }
        $centerX = ($base | Measure-Object X -Average).Average
        $centerY = ($base | Measure-Object Y -Average).Average
        $top = [Drawing.PointF[]]@($base | ForEach-Object {
            New-Point `
                ($centerX + ($_.X - $centerX) * 0.78) `
                ($centerY + ($_.Y - $centerY) * 0.78 - $height)
        })

        $sideColor = if ($isRuin) { New-Color '30373D' } else { New-Color '424B52' }
        for ($index = 0; $index -lt $base.Count; $index++) {
            $next = ($index + 1) % $base.Count
            Fill-Polygon $Graphics ([Drawing.PointF[]]@(
                $base[$index]
                $base[$next]
                $top[$next]
                $top[$index]
            )) $sideColor
        }

        $topColor = if ($isRuin) { New-Color '515B62' } else { New-Color '616C73' }
        Fill-Polygon $Graphics $top $topColor
        Stroke-Polygon $Graphics $top (New-Color 'DEE5E8' 105) 1
    }
}

function Draw-DebugOverlay {
    param($Graphics)

    $overlayColors = @{
        '.' = New-Color 'D8E0E4' 68
        '~' = New-Color '64C5E3' 100
        '#' = New-Color '353E45' 125
        'R' = New-Color '655167' 125
        'X' = New-Color '1F282F' 115
        'A' = New-Color '2F8FE7' 112
        'E' = New-Color 'DB5049' 112
    }
    $font = [Drawing.Font]::new(
        [Drawing.FontFamily]::GenericMonospace,
        10,
        [Drawing.FontStyle]::Bold,
        [Drawing.GraphicsUnit]::Pixel
    )
    $textBrush = [Drawing.SolidBrush]::new((New-Color '172129'))
    $centerBrush = [Drawing.SolidBrush]::new((New-Color '172129'))
    try {
        for ($y = 0; $y -lt $LogicalSize; $y++) {
            for ($x = 0; $x -lt $LogicalSize; $x++) {
                $symbol = Get-Symbol $x $y
                $diamond = Get-Diamond $x $y
                Fill-Polygon $Graphics $diamond $overlayColors[$symbol]
                Stroke-Polygon $Graphics $diamond (New-Color '172129' 180) 1
                $center = Get-CellCenter $x $y
                $Graphics.FillEllipse($centerBrush, $center.X - 2.5, $center.Y - 2.5, 5, 5)
                $Graphics.DrawString("$x,$y $symbol", $font, $textBrush, $center.X - 25, $center.Y - 18)
            }
        }

        $axisXEnd = New-Point ($Origin[0] + $AxisX[0] * 3) ($Origin[1] + $AxisX[1] * 3)
        $axisYEnd = New-Point ($Origin[0] + $AxisY[0] * 3) ($Origin[1] + $AxisY[1] * 3)
        $axisXPen = [Drawing.Pen]::new((New-Color 'D1463F'), 4)
        $axisYPen = [Drawing.Pen]::new((New-Color '2E75C9'), 4)
        $originBrush = [Drawing.SolidBrush]::new((New-Color 'FFD04A'))
        try {
            $Graphics.DrawLine($axisXPen, $Origin[0], $Origin[1], $axisXEnd.X, $axisXEnd.Y)
            $Graphics.DrawLine($axisYPen, $Origin[0], $Origin[1], $axisYEnd.X, $axisYEnd.Y)
            $Graphics.FillEllipse($originBrush, $Origin[0] - 7, $Origin[1] - 7, 14, 14)
            $Graphics.DrawString('origin=(1024,650)', $font, $textBrush, $Origin[0] + 12, $Origin[1] - 26)
            $Graphics.DrawString('axis_x=(48,24)', $font, $textBrush, $axisXEnd.X + 6, $axisXEnd.Y - 6)
            $Graphics.DrawString('axis_y=(-48,24)', $font, $textBrush, $axisYEnd.X - 110, $axisYEnd.Y - 6)
        } finally {
            $axisXPen.Dispose()
            $axisYPen.Dispose()
            $originBrush.Dispose()
        }
    } finally {
        $font.Dispose()
        $textBrush.Dispose()
        $centerBrush.Dispose()
    }
}

function New-IngameRender {
    param([ValidateSet('reference', 'clean', 'debug')][string]$Mode)

    $bitmap = [Drawing.Bitmap]::new(
        $CanvasSize,
        $CanvasSize,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    try {
        Fill-Rectangle $graphics 0 0 $CanvasSize $CanvasSize (New-Color 'D0D5D8')
        Draw-ContinuousEnvironment $graphics
        Draw-ExposedCliffs $graphics
        Draw-Ground $graphics ($Mode -ne 'clean')
        Draw-Obstacles $graphics
        if ($Mode -eq 'debug') {
            Draw-DebugOverlay $graphics
        }
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

$ExportModes = [ordered]@{
    'mountain_pass_blockout_ingame_reference.png' = 'reference'
    'mountain_pass_blockout_ingame_clean.png' = 'clean'
    'mountain_pass_blockout_ingame_debug.png' = 'debug'
}

foreach ($export in $ExportModes.GetEnumerator()) {
    $bitmap = New-IngameRender $export.Value
    $path = Join-Path $OutputDirectory $export.Key
    try {
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $bitmap.Dispose()
    }
    $saved = [Drawing.Image]::FromFile($path)
    try {
        Assert-Equal $saved.Width $CanvasSize "$($export.Key) width"
        Assert-Equal $saved.Height $CanvasSize "$($export.Key) height"
    } finally {
        $saved.Dispose()
    }
    Write-Output "EXPORTED $($export.Key) ${CanvasSize}x${CanvasSize}"
}

if (-not (Test-Path -LiteralPath $OldReferencePath)) {
    throw "Comparison source is missing: $OldReferencePath"
}

$comparisonPath = Join-Path $OutputDirectory 'mountain_pass_blockout_ingame_comparison.png'
$comparison = [Drawing.Bitmap]::new($CanvasSize, $CanvasSize, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$comparisonGraphics = [Drawing.Graphics]::FromImage($comparison)
$comparisonGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
$comparisonGraphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
try {
    Fill-Rectangle $comparisonGraphics 0 0 $CanvasSize $CanvasSize (New-Color 'BEC5C9')
    $oldImage = [Drawing.Image]::FromFile($OldReferencePath)
    $newImage = [Drawing.Image]::FromFile((Join-Path $OutputDirectory 'mountain_pass_blockout_ingame_reference.png'))
    try {
        $panelSize = 960
        $panelY = 544
        $oldRect = [Drawing.RectangleF]::new(48, $panelY, $panelSize, $panelSize)
        $newRect = [Drawing.RectangleF]::new(1040, $panelY, $panelSize, $panelSize)
        Fill-Rectangle $comparisonGraphics 42 ($panelY - 6) 972 972 (New-Color '465159')
        Fill-Rectangle $comparisonGraphics 1034 ($panelY - 6) 972 972 (New-Color '465159')
        $comparisonGraphics.DrawImage($oldImage, $oldRect)
        $comparisonGraphics.DrawImage($newImage, $newRect)
    } finally {
        $oldImage.Dispose()
        $newImage.Dispose()
    }
} finally {
    $comparisonGraphics.Dispose()
}
try {
    $comparison.Save($comparisonPath, [Drawing.Imaging.ImageFormat]::Png)
} finally {
    $comparison.Dispose()
}

$comparisonCheck = [Drawing.Image]::FromFile($comparisonPath)
try {
    Assert-Equal $comparisonCheck.Width $CanvasSize 'comparison width'
    Assert-Equal $comparisonCheck.Height $CanvasSize 'comparison height'
} finally {
    $comparisonCheck.Dispose()
}
Write-Output "EXPORTED mountain_pass_blockout_ingame_comparison.png ${CanvasSize}x${CanvasSize}"

if (-not ('IngameBlockoutImageValidator' -as [type])) {
    Add-Type -ReferencedAssemblies 'System.Drawing' -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;

public sealed class IngameBlockoutImageAnalysis
{
    public int MinX;
    public int MinY;
    public int MaxXExclusive;
    public int MaxYExclusive;
    public int Width;
    public int Height;
    public int ComponentCount;
    public int CenterSpineBackgroundGap;
}

public static class IngameBlockoutImageValidator
{
    public static IngameBlockoutImageAnalysis Analyze(string path)
    {
        using (Bitmap bitmap = new Bitmap(path))
        {
            int width = bitmap.Width;
            int height = bitmap.Height;
            int background = bitmap.GetPixel(0, 0).ToArgb();
            bool[] mask = new bool[width * height];
            int minX = width;
            int minY = height;
            int maxX = -1;
            int maxY = -1;

            for (int y = 0; y < height; y++)
            {
                int row = y * width;
                for (int x = 0; x < width; x++)
                {
                    if (bitmap.GetPixel(x, y).ToArgb() == background)
                        continue;

                    mask[row + x] = true;
                    if (x < minX) minX = x;
                    if (x > maxX) maxX = x;
                    if (y < minY) minY = y;
                    if (y > maxY) maxY = y;
                }
            }

            int components = 0;
            bool[] visited = new bool[mask.Length];
            Queue<int> queue = new Queue<int>();
            for (int index = 0; index < mask.Length; index++)
            {
                if (!mask[index] || visited[index])
                    continue;

                components++;
                visited[index] = true;
                queue.Enqueue(index);
                while (queue.Count > 0)
                {
                    int current = queue.Dequeue();
                    int x = current % width;
                    int y = current / width;
                    int candidate;

                    if (x > 0)
                    {
                        candidate = current - 1;
                        if (mask[candidate] && !visited[candidate]) { visited[candidate] = true; queue.Enqueue(candidate); }
                    }
                    if (x + 1 < width)
                    {
                        candidate = current + 1;
                        if (mask[candidate] && !visited[candidate]) { visited[candidate] = true; queue.Enqueue(candidate); }
                    }
                    if (y > 0)
                    {
                        candidate = current - width;
                        if (mask[candidate] && !visited[candidate]) { visited[candidate] = true; queue.Enqueue(candidate); }
                    }
                    if (y + 1 < height)
                    {
                        candidate = current + width;
                        if (mask[candidate] && !visited[candidate]) { visited[candidate] = true; queue.Enqueue(candidate); }
                    }
                }
            }

            int centerX = width / 2;
            int first = -1;
            int last = -1;
            for (int y = 0; y < height; y++)
            {
                if (!mask[y * width + centerX]) continue;
                if (first < 0) first = y;
                last = y;
            }
            int centerGap = 0;
            if (first >= 0)
            {
                for (int y = first; y <= last; y++)
                    if (!mask[y * width + centerX]) centerGap++;
            }

            return new IngameBlockoutImageAnalysis
            {
                MinX = minX,
                MinY = minY,
                MaxXExclusive = maxX + 1,
                MaxYExclusive = maxY + 1,
                Width = maxX - minX + 1,
                Height = maxY - minY + 1,
                ComponentCount = components,
                CenterSpineBackgroundGap = centerGap
            };
        }
    }
}
'@
}

$referencePath = Join-Path $OutputDirectory 'mountain_pass_blockout_ingame_reference.png'
$imageAnalysis = [IngameBlockoutImageValidator]::Analyze($referencePath)
Assert-Equal $imageAnalysis.MinX 184 'rendered platform bbox left'
Assert-Equal $imageAnalysis.MinY 360 'rendered platform bbox top'
Assert-Equal $imageAnalysis.MaxXExclusive 1864 'rendered platform bbox right'
Assert-Equal $imageAnalysis.MaxYExclusive 1660 'rendered platform bbox bottom'
Assert-Equal $imageAnalysis.Width 1680 'rendered platform bbox width'
Assert-Equal $imageAnalysis.Height 1300 'rendered platform bbox height'
Assert-Equal $imageAnalysis.ComponentCount 1 'rendered topology component count'
Assert-Equal $imageAnalysis.CenterSpineBackgroundGap 0 'center gap between platform and environment'

$sceneWidthPercent = ($SceneBounds.Width / $CanvasSize) * 100.0
if ($sceneWidthPercent -lt 75.0 -or $sceneWidthPercent -gt 85.0) {
    throw "Continuous platform width is outside the requested range: $sceneWidthPercent%"
}

$allCellPoints = [Collections.Generic.List[Drawing.PointF]]::new()
$walkablePoints = [Collections.Generic.List[Drawing.PointF]]::new()
for ($y = 0; $y -lt $LogicalSize; $y++) {
    for ($x = 0; $x -lt $LogicalSize; $x++) {
        $allCellPoints.AddRange([Drawing.PointF[]](Get-Diamond $x $y))
        if ((Get-Symbol $x $y) -ne 'X') {
            $walkablePoints.AddRange([Drawing.PointF[]](Get-Diamond $x $y))
        }
    }
}

function Get-PointBounds {
    param([Drawing.PointF[]]$Points)

    $minX = ($Points | Measure-Object X -Minimum).Minimum
    $minY = ($Points | Measure-Object Y -Minimum).Minimum
    $maxX = ($Points | Measure-Object X -Maximum).Maximum
    $maxY = ($Points | Measure-Object Y -Maximum).Maximum
    return [Drawing.RectangleF]::FromLTRB($minX, $minY, $maxX, $maxY)
}

$gridBounds = Get-PointBounds ([Drawing.PointF[]]$allCellPoints.ToArray())
$playableBounds = Get-PointBounds ([Drawing.PointF[]]$walkablePoints.ToArray())
Assert-Equal $gridBounds.X 352 'full grid bbox left'
Assert-Equal $gridBounds.Y 626 'full grid bbox top'
Assert-Equal $gridBounds.Width 1344 'full grid bbox width'
Assert-Equal $gridBounds.Height 672 'full grid bbox height'
Assert-Equal $playableBounds.X 496 'playable bbox left'
Assert-Equal $playableBounds.Y 698 'playable bbox top'
Assert-Equal $playableBounds.Width 1056 'playable bbox width'
Assert-Equal $playableBounds.Height 528 'playable bbox height'

Write-Output ('VALIDATED canvas={0}x{0}' -f $CanvasSize)
Write-Output ('VALIDATED continuous_platform_bbox=({0},{1})-({2},{3}) size={4}x{5}' -f `
    $SceneBounds.Left, $SceneBounds.Top, $SceneBounds.Right, $SceneBounds.Bottom, `
    $SceneBounds.Width, $SceneBounds.Height)
Write-Output ('VALIDATED continuous_platform_width_percent={0:N4}' -f $sceneWidthPercent)
Write-Output ('VALIDATED rendered_pixel_components={0} center_spine_background_gap_px={1}' -f `
    $imageAnalysis.ComponentCount, $imageAnalysis.CenterSpineBackgroundGap)
Write-Output ('VALIDATED playable_surface_bbox=({0},{1})-({2},{3}) size={4}x{5}' -f `
    $playableBounds.Left, $playableBounds.Top, $playableBounds.Right, $playableBounds.Bottom, `
    $playableBounds.Width, $playableBounds.Height)
Write-Output ('VALIDATED full_grid_bbox=({0},{1})-({2},{3}) size={4}x{5}' -f `
    $gridBounds.Left, $gridBounds.Top, $gridBounds.Right, $gridBounds.Bottom, `
    $gridBounds.Width, $gridBounds.Height)
Write-Output 'VALIDATED logical_grid=14x14 cells=196 void=32 ice=8 obstacles=7 ruins=4 zone_a=6 zone_e=6'
Write-Output 'VALIDATED topology_components=1 detached_decorative_shapes=0 gameplay_data_writes=0'
