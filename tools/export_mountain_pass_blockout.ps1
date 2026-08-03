param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $ProjectRoot 'data\maps\mountain_pass_blockout.tres'
$source = Get-Content -Raw -LiteralPath $sourcePath
$outputDir = Join-Path $ProjectRoot 'artifacts\maps\mountain_pass_blueprint'
$legacyReference = Join-Path $ProjectRoot 'artifacts\maps\mountain_pass_blockout\mountain_pass_blockout_reference.png'
$null = New-Item -ItemType Directory -Force $outputDir

$CanvasWidth = 1920
$CanvasHeight = 1080
$Origin = @(960.0, 232.0)
$AxisX = @(48.0, 24.0)
$AxisY = @(-48.0, 24.0)

function Match-Value([string]$pattern) {
    $match = [regex]::Match($source, $pattern)
    if (-not $match.Success) { throw "Missing $pattern in $sourcePath" }
    $match.Groups[1].Value
}

$layoutText = Match-Value 'layout_rows\s*=\s*PackedStringArray\(([^\r\n]+)\)'
$Rows = @([regex]::Matches($layoutText, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($Rows.Count -ne 14 -or @($Rows | Where-Object Length -ne 14).Count -ne 0) {
    throw 'The authoritative layout must remain exactly 14x14.'
}

$RoadCells = [Collections.Generic.HashSet[string]]::new()
$roadText = Match-Value 'road_visual_cells\s*=\s*Array\[Vector2i\]\(([^\r\n]+)\)'
foreach ($match in [regex]::Matches($roadText, 'Vector2i\((\d+),\s*(\d+)\)')) {
    $null = $RoadCells.Add("$($match.Groups[1].Value),$($match.Groups[2].Value)")
}

function Color([string]$hex, [int]$alpha = 255) {
    $value = $hex.TrimStart('#')
    [Drawing.Color]::FromArgb(
        $alpha,
        [Convert]::ToInt32($value.Substring(0, 2), 16),
        [Convert]::ToInt32($value.Substring(2, 2), 16),
        [Convert]::ToInt32($value.Substring(4, 2), 16)
    )
}

function Point([single]$x, [single]$y) { [Drawing.PointF]::new($x, $y) }

function Symbol-At([int]$x, [int]$y) {
    if ($x -lt 0 -or $x -ge 14 -or $y -lt 0 -or $y -ge 14) { return 'X' }
    $Rows[$y].Substring($x, 1)
}

function Center([int]$x, [int]$y) {
    Point ($Origin[0] + $x * $AxisX[0] + $y * $AxisY[0]) ($Origin[1] + $x * $AxisX[1] + $y * $AxisY[1])
}

function Diamond([int]$x, [int]$y) {
    $center = Center $x $y
    [Drawing.PointF[]]@(
        (Point $center.X ($center.Y - 24)),
        (Point ($center.X + 48) $center.Y),
        (Point $center.X ($center.Y + 24)),
        (Point ($center.X - 48) $center.Y)
    )
}

function Fill-Polygon($graphics, [Drawing.PointF[]]$points, [Drawing.Color]$color) {
    $brush = [Drawing.SolidBrush]::new($color)
    try { $graphics.FillPolygon($brush, $points) } finally { $brush.Dispose() }
}

function Stroke-Polygon($graphics, [Drawing.PointF[]]$points, [Drawing.Color]$color, [single]$width = 1) {
    $pen = [Drawing.Pen]::new($color, $width)
    $pen.LineJoin = [Drawing.Drawing2D.LineJoin]::Round
    try { $graphics.DrawPolygon($pen, $points) } finally { $pen.Dispose() }
}

function Fill-Rectangle($graphics, [single]$x, [single]$y, [single]$width, [single]$height, [Drawing.Color]$color) {
    $brush = [Drawing.SolidBrush]::new($color)
    try { $graphics.FillRectangle($brush, $x, $y, $width, $height) } finally { $brush.Dispose() }
}

function Stroke-Rectangle($graphics, [single]$x, [single]$y, [single]$width, [single]$height, [Drawing.Color]$color, [single]$strokeWidth = 1) {
    $pen = [Drawing.Pen]::new($color, $strokeWidth)
    try { $graphics.DrawRectangle($pen, $x, $y, $width, $height) } finally { $pen.Dispose() }
}

function All-Cells {
    $cells = [Collections.Generic.List[object]]::new()
    for ($y = 0; $y -lt 14; $y++) {
        for ($x = 0; $x -lt 14; $x++) {
            $center = Center $x $y
            $cells.Add([pscustomobject]@{ X = $x; Y = $y; Center = $center; Depth = $center.Y })
        }
    }
    @($cells | Sort-Object Depth, @{ Expression = { $_.Center.X } })
}

function Connected-Groups([string]$target) {
    $remaining = [Collections.Generic.HashSet[string]]::new()
    for ($y = 0; $y -lt 14; $y++) {
        for ($x = 0; $x -lt 14; $x++) {
            if ((Symbol-At $x $y) -eq $target) { $null = $remaining.Add("$x,$y") }
        }
    }
    $groups = [Collections.Generic.List[object]]::new()
    while ($remaining.Count -gt 0) {
        $seed = @($remaining)[0]
        $queue = [Collections.Generic.Queue[string]]::new()
        $cells = [Collections.Generic.List[object]]::new()
        $queue.Enqueue($seed)
        $null = $remaining.Remove($seed)
        while ($queue.Count -gt 0) {
            $parts = $queue.Dequeue().Split(',')
            $x = [int]$parts[0]
            $y = [int]$parts[1]
            $cells.Add([pscustomobject]@{ X = $x; Y = $y; Center = (Center $x $y) })
            foreach ($direction in @(@(0, -1), @(1, 0), @(0, 1), @(-1, 0))) {
                $key = "$($x + $direction[0]),$($y + $direction[1])"
                if ($remaining.Remove($key)) { $queue.Enqueue($key) }
            }
        }
        $groups.Add([pscustomobject]@{ Cells = [object[]]$cells.ToArray() })
    }
    @($groups)
}

function Platform-VoidEdges {
    $directions = @(
        @{ Name = 'UP'; DX = 0; DY = -1; A = 0; B = 1; SX = 48.0; SY = -24.0 },
        @{ Name = 'RIGHT'; DX = 1; DY = 0; A = 1; B = 2; SX = 48.0; SY = 24.0 },
        @{ Name = 'DOWN'; DX = 0; DY = 1; A = 2; B = 3; SX = -48.0; SY = 24.0 },
        @{ Name = 'LEFT'; DX = -1; DY = 0; A = 3; B = 0; SX = -48.0; SY = -24.0 }
    )
    $edges = [Collections.Generic.List[object]]::new()
    foreach ($cell in (All-Cells)) {
        if ((Symbol-At $cell.X $cell.Y) -eq 'X') { continue }
        $diamond = Diamond $cell.X $cell.Y
        foreach ($direction in $directions) {
            $nx = $cell.X + $direction.DX
            $ny = $cell.Y + $direction.DY
            if ($nx -lt 0 -or $nx -ge 14 -or $ny -lt 0 -or $ny -ge 14) { continue }
            if ((Symbol-At $nx $ny) -ne 'X') { continue }
            $a = $diamond[$direction.A]
            $b = $diamond[$direction.B]
            $edges.Add([pscustomobject]@{
                Name = $direction.Name; A = $a; B = $b
                SX = $direction.SX; SY = $direction.SY
                Depth = ($a.Y + $b.Y) / 2
            })
        }
    }
    @($edges | Sort-Object Depth)
}

function Convex-Hull([Drawing.PointF[]]$inputPoints) {
    $unique = @{}
    foreach ($point in $inputPoints) { $unique["$($point.X),$($point.Y)"] = $point }
    $points = @($unique.Values | Sort-Object X, Y)
    function Cross($origin, $a, $b) {
        (($a.X - $origin.X) * ($b.Y - $origin.Y)) - (($a.Y - $origin.Y) * ($b.X - $origin.X))
    }
    $lower = [Collections.Generic.List[Drawing.PointF]]::new()
    foreach ($point in $points) {
        while ($lower.Count -ge 2 -and (Cross $lower[$lower.Count - 2] $lower[$lower.Count - 1] $point) -le 0) {
            $lower.RemoveAt($lower.Count - 1)
        }
        $lower.Add($point)
    }
    $upper = [Collections.Generic.List[Drawing.PointF]]::new()
    for ($index = $points.Count - 1; $index -ge 0; $index--) {
        $point = $points[$index]
        while ($upper.Count -ge 2 -and (Cross $upper[$upper.Count - 2] $upper[$upper.Count - 1] $point) -le 0) {
            $upper.RemoveAt($upper.Count - 1)
        }
        $upper.Add($point)
    }
    $lower.RemoveAt($lower.Count - 1)
    $upper.RemoveAt($upper.Count - 1)
    [Drawing.PointF[]]@($lower.ToArray() + $upper.ToArray())
}

$Palette = @{
    Sky = Color 'dce9ef'
    Distant = Color 'c7d5dd'
    Mountain = Color '91a5b1'
    MountainSnow = Color 'd9e3e8'
    RearCliff = Color '667b88'
    NonPlayableSnow = Color 'e1e8eb'
    WalkableSnow = Color 'f4f7f7'
    Road = Color 'c8c1b3'
    Ice = Color '9fd8e8'
    Rock = Color '53636d'
    Ruin = Color '343f47'
    Ravine = Color '354b58'
    RavineDeep = Color '263944'
    FrontCliff = Color '435966'
    Grid = Color '213843' 118
    GridStrong = Color '142630' 194
    Guide = Color '1fb2ab' 158
}

$LogicColors = @{
    '.' = Color 'e8eef0'
    '~' = Color '73cce5'
    '#' = Color '4c5962'
    'R' = Color '66506b'
    'X' = Color '263a46'
    'A' = Color '328ee6'
    'E' = Color 'dc554d'
}

function Draw-DistantEnvironment($graphics) {
    Fill-Rectangle $graphics 0 0 $CanvasWidth $CanvasHeight $Palette.Sky
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 92), (Point 1920 92), (Point 1920 360), (Point 0 410))) $Palette.Distant
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 390), (Point 0 165), (Point 170 280), (Point 340 118), (Point 520 286), (Point 690 150), (Point 820 334), (Point 820 420))) $Palette.Mountain
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1100 410), (Point 1100 320), (Point 1260 145), (Point 1400 285), (Point 1580 105), (Point 1750 270), (Point 1920 155), (Point 1920 430))) $Palette.Mountain
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 40 348), (Point 170 268), (Point 340 135), (Point 505 292), (Point 680 170), (Point 800 338), (Point 800 370), (Point 40 405))) $Palette.MountainSnow
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1120 350), (Point 1260 165), (Point 1400 302), (Point 1580 125), (Point 1748 288), (Point 1920 178), (Point 1920 385), (Point 1120 390))) $Palette.MountainSnow
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 375), (Point 330 330), (Point 650 390), (Point 790 474), (Point 595 530), (Point 275 505), (Point 0 600))) $Palette.RearCliff
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1920 365), (Point 1600 325), (Point 1330 378), (Point 1160 460), (Point 1335 520), (Point 1645 500), (Point 1920 585))) $Palette.RearCliff
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 505), (Point 340 430), (Point 665 500), (Point 780 620), (Point 650 820), (Point 320 955), (Point 0 935))) $Palette.NonPlayableSnow
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1920 490), (Point 1600 425), (Point 1300 495), (Point 1160 610), (Point 1290 815), (Point 1600 945), (Point 1920 925))) $Palette.NonPlayableSnow
    Fill-Rectangle $graphics 0 850 1920 230 (Color 'dbe4e8')
}

function Draw-RoadApproaches($graphics) {
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 815), (Point 0 900), (Point 360 780), (Point 610 690), (Point 725 615), (Point 645 560), (Point 500 630), (Point 260 720))) $Palette.Road
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1260 520), (Point 1400 445), (Point 1610 368), (Point 1920 300), (Point 1920 375), (Point 1650 430), (Point 1440 505), (Point 1330 570))) $Palette.Road
}

function Draw-VoidLandscape($graphics) {
    $groupIndex = 0
    foreach ($wrapper in (Connected-Groups 'X')) {
        $points = [Collections.Generic.List[Drawing.PointF]]::new()
        foreach ($cell in $wrapper.Cells) { $points.AddRange([Drawing.PointF[]](Diamond $cell.X $cell.Y)) }
        $hull = Convex-Hull ([Drawing.PointF[]]$points.ToArray())
        $centerX = ($hull | Measure-Object X -Average).Average
        $centerY = ($hull | Measure-Object Y -Average).Average
        $ravine = [Drawing.PointF[]]@(
            for ($index = 0; $index -lt $hull.Count; $index++) {
                $factor = 1.08 + 0.035 * ($index % 2)
                Point ($centerX + ($hull[$index].X - $centerX) * $factor) ($centerY + ($hull[$index].Y - $centerY) * $factor)
            }
        )
        $color = if ($groupIndex % 2 -eq 0) { $Palette.RavineDeep } else { $Palette.Ravine }
        Fill-Polygon $graphics $ravine $color
        $depth = [Drawing.PointF[]]@($ravine | ForEach-Object { Point ($centerX + ($_.X - $centerX) * 0.67) ($centerY + ($_.Y - $centerY) * 0.67 + 7) })
        Fill-Polygon $graphics $depth $(if ($groupIndex % 2 -eq 0) { Color '1e303a' } else { Color '2b404b' })
        Stroke-Polygon $graphics $depth (Color '455e6a') 1.5
        $groupIndex++
    }
}

function Draw-GridTerrain($graphics) {
    foreach ($cell in (All-Cells)) {
        $symbol = Symbol-At $cell.X $cell.Y
        if ($symbol -eq 'X') { continue }
        $key = "$($cell.X),$($cell.Y)"
        $color = $Palette.WalkableSnow
        if ($symbol -eq '~') { $color = $Palette.Ice }
        elseif ($RoadCells.Contains($key)) { $color = $Palette.Road }
        Fill-Polygon $graphics (Diamond $cell.X $cell.Y) $color
    }
}

function Draw-CliffTransitions($graphics) {
    foreach ($edge in (Platform-VoidEdges)) {
        $offsetX = $edge.SX * 0.46
        $offsetY = $edge.SY * 0.46
        $face = [Drawing.PointF[]]@($edge.A, $edge.B, (Point ($edge.B.X + $offsetX) ($edge.B.Y + $offsetY)), (Point ($edge.A.X + $offsetX) ($edge.A.Y + $offsetY)))
        $color = if ($edge.Name -in @('RIGHT', 'DOWN')) { $Palette.FrontCliff } else { $Palette.RearCliff }
        Fill-Polygon $graphics $face $color
        $lipPen = [Drawing.Pen]::new((Color '82949e'), 2)
        $innerPen = [Drawing.Pen]::new((Color '354954'), 1.5)
        try {
            $graphics.DrawLine($lipPen, $edge.A, $edge.B)
            $innerA = Point ($edge.A.X + $offsetX * 0.76) ($edge.A.Y + $offsetY * 0.76)
            $innerB = Point ($edge.B.X + $offsetX * 0.76) ($edge.B.Y + $offsetY * 0.76)
            $graphics.DrawLine($innerPen, $innerA, $innerB)
        } finally { $lipPen.Dispose(); $innerPen.Dispose() }
    }
}

function Draw-Obstacles($graphics) {
    $wrappers = @((Connected-Groups '#') + (Connected-Groups 'R'))
    $ordered = @($wrappers | Sort-Object { ($_.Cells | ForEach-Object { $_.Center.Y } | Measure-Object -Maximum).Maximum })
    foreach ($wrapper in $ordered) {
        $group = @($wrapper.Cells)
        $points = [Collections.Generic.List[Drawing.PointF]]::new()
        foreach ($cell in $group) { $points.AddRange([Drawing.PointF[]](Diamond $cell.X $cell.Y)) }
        $hull = Convex-Hull ([Drawing.PointF[]]$points.ToArray())
        $centerX = ($hull | Measure-Object X -Average).Average
        $centerY = ($hull | Measure-Object Y -Average).Average
        $ruin = (Symbol-At $group[0].X $group[0].Y) -eq 'R'
        $height = if ($ruin) { 14.0 } elseif ($group.Count -eq 2) { 12.0 } else { 10.0 }
        $insetFactor = if ($group.Count -ge 4) { 0.84 } elseif ($group.Count -eq 2) { 0.80 } else { 0.72 }
        $base = [Drawing.PointF[]]@($hull | ForEach-Object { Point ($centerX + ($_.X - $centerX) * $insetFactor) ($centerY + ($_.Y - $centerY) * $insetFactor) })
        $top = [Drawing.PointF[]]@($base | ForEach-Object { Point ($centerX + ($_.X - $centerX) * 0.96) ($centerY + ($_.Y - $centerY) * 0.96 - $height) })
        $topColor = if ($ruin) { $Palette.Ruin } else { $Palette.Rock }
        $sideColor = if ($ruin) { Color '283138' } else { Color '414f58' }
        for ($index = 0; $index -lt $base.Count; $index++) {
            $next = ($index + 1) % $base.Count
            Fill-Polygon $graphics ([Drawing.PointF[]]@($base[$index], $base[$next], $top[$next], $top[$index])) $sideColor
        }
        Fill-Polygon $graphics $top $topColor
        Stroke-Polygon $graphics $base (Color '2a363e') 1.5
        Stroke-Polygon $graphics $top $(if ($ruin) { Color '76838a' } else { Color '81919a' }) 2
        if ($ruin) {
            $ruinPen = [Drawing.Pen]::new((Color '77858c'), 5)
            try {
                $graphics.DrawLines($ruinPen, [Drawing.PointF[]]@((Point ($centerX - 56) ($centerY - $height - 5)), (Point ($centerX + 8) ($centerY - $height - 5)), (Point ($centerX + 43) ($centerY - $height + 2))))
            } finally { $ruinPen.Dispose() }
        }
    }
}

function Draw-FrontCliffs($graphics) {
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 905), (Point 250 925), (Point 430 875), (Point 520 930), (Point 405 1080), (Point 0 1080))) $Palette.FrontCliff
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1920 900), (Point 1680 925), (Point 1510 875), (Point 1425 940), (Point 1540 1080), (Point 1920 1080))) $Palette.FrontCliff
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 900), (Point 245 914), (Point 410 870), (Point 475 910), (Point 360 950), (Point 0 965))) $Palette.MountainSnow
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 1920 895), (Point 1680 914), (Point 1525 870), (Point 1460 915), (Point 1570 950), (Point 1920 960))) $Palette.MountainSnow
}

function Draw-ReferenceGrid($graphics) {
    foreach ($cell in (All-Cells)) {
        if ((Symbol-At $cell.X $cell.Y) -ne 'X') { Stroke-Polygon $graphics (Diamond $cell.X $cell.Y) $Palette.Grid 1 }
    }
}

function Draw-Logic($graphics) {
    Fill-Rectangle $graphics 0 0 1920 1080 (Color 'd6e2e8')
    Fill-Polygon $graphics ([Drawing.PointF[]]@((Point 0 390), (Point 340 140), (Point 690 370), (Point 960 250), (Point 1260 370), (Point 1590 130), (Point 1920 385), (Point 1920 1080), (Point 0 1080))) (Color 'b9c8d0')
    foreach ($cell in (All-Cells)) {
        $symbol = Symbol-At $cell.X $cell.Y
        Fill-Polygon $graphics (Diamond $cell.X $cell.Y) $LogicColors[$symbol]
        Stroke-Polygon $graphics (Diamond $cell.X $cell.Y) $Palette.GridStrong 1
        $brush = [Drawing.SolidBrush]::new($Palette.GridStrong)
        try { $graphics.FillEllipse($brush, $cell.Center.X - 2.4, $cell.Center.Y - 2.4, 4.8, 4.8) } finally { $brush.Dispose() }
    }
    foreach ($wrapper in @((Connected-Groups '#') + (Connected-Groups 'R'))) {
        $points = [Collections.Generic.List[Drawing.PointF]]::new()
        foreach ($cell in $wrapper.Cells) { $points.AddRange([Drawing.PointF[]](Diamond $cell.X $cell.Y)) }
        Stroke-Polygon $graphics (Convex-Hull ([Drawing.PointF[]]$points.ToArray())) (Color '141f26' 215) 2.5
    }
}

function Draw-ForegroundGuide($graphics) {
    $left = [Drawing.PointF[]]@((Point 0 930), (Point 90 897), (Point 205 920), (Point 295 1005), (Point 270 1080), (Point 0 1080))
    $right = [Drawing.PointF[]]@((Point 1920 925), (Point 1825 897), (Point 1710 925), (Point 1625 1010), (Point 1650 1080), (Point 1920 1080))
    foreach ($polygon in @($left, $right)) { Fill-Polygon $graphics $polygon $Palette.Guide; Stroke-Polygon $graphics $polygon (Color '77ddd8' 205) 2 }
}

function Draw-Debug($graphics) {
    $font = [Drawing.Font]::new([Drawing.FontFamily]::GenericMonospace, 9, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $labelFont = [Drawing.Font]::new([Drawing.FontFamily]::GenericMonospace, 14, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $brush = [Drawing.SolidBrush]::new((Color '14242d'))
    try {
        foreach ($cell in (All-Cells)) {
            $symbol = Symbol-At $cell.X $cell.Y
            $overlay = [Drawing.Color]::FromArgb($(if ($symbol -eq 'X') { 170 } else { 108 }), $LogicColors[$symbol])
            Fill-Polygon $graphics (Diamond $cell.X $cell.Y) $overlay
            Stroke-Polygon $graphics (Diamond $cell.X $cell.Y) $Palette.GridStrong 1
            $graphics.FillEllipse($brush, $cell.Center.X - 2.8, $cell.Center.Y - 2.8, 5.6, 5.6)
            $graphics.DrawString("$($cell.X),$($cell.Y) $symbol", $font, $brush, $cell.Center.X - 24, $cell.Center.Y - 15)
        }
        Stroke-Rectangle $graphics 288 208 1344 672 (Color 'e43c92') 3
        Stroke-Rectangle $graphics 24 72 1872 984 (Color '21a87d') 3
        $originBrush = [Drawing.SolidBrush]::new((Color 'ffd14d'))
        try { $graphics.FillEllipse($originBrush, 953, 225, 14, 14) } finally { $originBrush.Dispose() }
        $graphics.DrawString('ORIGIN 960,232', $labelFont, $brush, 972, 216)
        $graphics.DrawString('GRID BOUNDS 288,208 1344x672', $labelFont, $brush, 300, 178)
        $graphics.DrawString('SCENE USEFUL 24,72 1872x984', $labelFont, $brush, 36, 80)
        $axisXPen = [Drawing.Pen]::new((Color 'ed9136'), 4)
        $axisYPen = [Drawing.Pen]::new((Color '43aee5'), 4)
        try {
            $graphics.DrawLine($axisXPen, 960, 232, 1056, 280)
            $graphics.DrawLine($axisYPen, 960, 232, 864, 280)
        } finally { $axisXPen.Dispose(); $axisYPen.Dispose() }
        $graphics.DrawString('axis_x 48,24', $font, $brush, 1062, 274)
        $graphics.DrawString('axis_y -48,24', $font, $brush, 775, 274)
    } finally { $font.Dispose(); $labelFont.Dispose(); $brush.Dispose() }
}

function New-Canvas([bool]$transparent) {
    $bitmap = [Drawing.Bitmap]::new($CanvasWidth, $CanvasHeight, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    if ($transparent) { $graphics.Clear([Drawing.Color]::Transparent) }
    [pscustomobject]@{ Bitmap = $bitmap; Graphics = $graphics }
}

function Render([string]$mode) {
    $canvas = New-Canvas ($mode -eq 'foreground')
    try {
        if ($mode -eq 'logic') { Draw-Logic $canvas.Graphics }
        elseif ($mode -eq 'foreground') { Draw-ForegroundGuide $canvas.Graphics }
        else {
            Draw-DistantEnvironment $canvas.Graphics
            Draw-RoadApproaches $canvas.Graphics
            Draw-VoidLandscape $canvas.Graphics
            Draw-GridTerrain $canvas.Graphics
            Draw-CliffTransitions $canvas.Graphics
            if ($mode -eq 'reference') { Draw-ReferenceGrid $canvas.Graphics }
            Draw-Obstacles $canvas.Graphics
            Draw-FrontCliffs $canvas.Graphics
            if ($mode -eq 'debug') { Draw-Debug $canvas.Graphics }
        }
    } finally { $canvas.Graphics.Dispose() }
    $canvas.Bitmap
}

$exports = [ordered]@{
    'mountain_pass_blueprint_reference.png' = 'reference'
    'mountain_pass_blueprint_clean.png' = 'clean'
    'mountain_pass_blueprint_logic.png' = 'logic'
    'mountain_pass_blueprint_foreground_guide.png' = 'foreground'
    'mountain_pass_blueprint_debug.png' = 'debug'
}

foreach ($entry in $exports.GetEnumerator()) {
    $bitmap = Render $entry.Value
    $path = Join-Path $outputDir $entry.Key
    try { $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png) } finally { $bitmap.Dispose() }
    "EXPORTED $($entry.Key) 1920x1080"
}

if (-not (Test-Path -LiteralPath $legacyReference)) {
    throw "Legacy diorama is required for comparison: $legacyReference"
}

$comparison = New-Canvas $false
try {
    Fill-Rectangle $comparison.Graphics 0 0 1920 1080 (Color 'd9e5ea')
    $panels = @(
        @{ X = 32; Path = $legacyReference; Title = 'ANCIEN DIORAMA / OBJET ISOLE' },
        @{ X = 984; Path = (Join-Path $outputDir 'mountain_pass_blueprint_clean.png'); Title = 'NOUVEAU BLUEPRINT / CADRAGE IN-GAME' }
    )
    $titleFont = [Drawing.Font]::new([Drawing.FontFamily]::GenericSansSerif, 20, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $titleBrush = [Drawing.SolidBrush]::new((Color 'f4f7f8'))
    $format = [Drawing.StringFormat]::new()
    $format.Alignment = [Drawing.StringAlignment]::Center
    try {
        foreach ($panel in $panels) {
            Fill-Rectangle $comparison.Graphics $panel.X 96 904 952 (Color '465b67')
            $comparison.Graphics.DrawString($panel.Title, $titleFont, $titleBrush, [Drawing.RectangleF]::new($panel.X + 20, 108, 864, 36), $format)
            $image = [Drawing.Image]::FromFile($panel.Path)
            try {
                $availableWidth = 864.0
                $availableHeight = 870.0
                $scale = [Math]::Min($availableWidth / $image.Width, $availableHeight / $image.Height)
                $width = [single]($image.Width * $scale)
                $height = [single]($image.Height * $scale)
                $x = [single]($panel.X + 20 + ($availableWidth - $width) / 2)
                $y = [single](158 + ($availableHeight - $height) / 2)
                $comparison.Graphics.DrawImage($image, [Drawing.RectangleF]::new($x, $y, $width, $height))
            } finally { $image.Dispose() }
        }
    } finally { $titleFont.Dispose(); $titleBrush.Dispose(); $format.Dispose() }
} finally { $comparison.Graphics.Dispose() }

$comparisonPath = Join-Path $outputDir 'mountain_pass_blueprint_comparison.png'
try { $comparison.Bitmap.Save($comparisonPath, [Drawing.Imaging.ImageFormat]::Png) } finally { $comparison.Bitmap.Dispose() }
'EXPORTED mountain_pass_blueprint_comparison.png 1920x1080'
