param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$dataPath = Join-Path $ProjectRoot 'data\maps\mountain_pass_blockout.tres'
$outputDir = Join-Path $ProjectRoot 'artifacts\maps\mountain_pass_blockout'
$source = Get-Content -Raw -LiteralPath $dataPath
$null = New-Item -ItemType Directory -Force -Path $outputDir

function Match-Value([string]$pattern) {
    $match = [regex]::Match($source, $pattern)
    if (-not $match.Success) { throw "Calibration absente: $pattern" }
    return $match.Groups[1].Value
}

$layoutText = Match-Value 'layout_rows\s*=\s*PackedStringArray\(([^\r\n]+)\)'
$rows = @([regex]::Matches($layoutText, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($rows.Count -ne 14) { throw "Le layout doit contenir 14 lignes, obtenu: $($rows.Count)" }

function Read-Vector([string]$name) {
    $match = [regex]::Match($source, "$name\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)")
    if (-not $match.Success) { throw "Vecteur absent: $name" }
    return @([single]$match.Groups[1].Value, [single]$match.Groups[2].Value)
}

$origin = Read-Vector 'grid_origin'
$axisX = Read-Vector 'axis_x'
$axisY = Read-Vector 'axis_y'
$cliffDepth = [single](Match-Value 'cliff_depth\s*=\s*([\d.]+)')
$obstacleHeight = [single](Match-Value 'obstacle_height\s*=\s*([\d.]+)')
$landmarkHeight = [single](Match-Value 'landmark_height\s*=\s*([\d.]+)')

$roadCells = [System.Collections.Generic.HashSet[string]]::new()
$roadText = Match-Value 'road_visual_cells\s*=\s*Array\[Vector2i\]\(([^\r\n]+)\)'
foreach ($match in [regex]::Matches($roadText, 'Vector2i\((\d+),\s*(\d+)\)')) {
    $null = $roadCells.Add("$($match.Groups[1].Value),$($match.Groups[2].Value)")
}

function Color([string]$hex, [int]$alpha = 255) {
    $value = $hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(
        $alpha,
        [Convert]::ToInt32($value.Substring(0, 2), 16),
        [Convert]::ToInt32($value.Substring(2, 2), 16),
        [Convert]::ToInt32($value.Substring(4, 2), 16)
    )
}

function Point([single]$x, [single]$y) { return [System.Drawing.PointF]::new($x, $y) }

function Symbol([int]$x, [int]$y) {
    if ($x -lt 0 -or $x -ge 14 -or $y -lt 0 -or $y -ge 14) { return 'X' }
    return $rows[$y].Substring($x, 1)
}

function Center([int]$x, [int]$y) {
    return Point ($origin[0] + $x * $axisX[0] + $y * $axisY[0]) ($origin[1] + $x * $axisX[1] + $y * $axisY[1])
}

function Diamond([int]$x, [int]$y) {
    $center = Center $x $y
    $halfWidth = [Math]::Abs($axisX[0] - $axisY[0]) * 0.5
    $halfHeight = [Math]::Abs($axisX[1] + $axisY[1]) * 0.5
    return [System.Drawing.PointF[]]@(
        (Point $center.X ($center.Y - $halfHeight)),
        (Point ($center.X + $halfWidth) $center.Y),
        (Point $center.X ($center.Y + $halfHeight)),
        (Point ($center.X - $halfWidth) $center.Y)
    )
}

function Fill-Poly($graphics, [System.Drawing.PointF[]]$points, [System.Drawing.Color]$color) {
    $brush = [System.Drawing.SolidBrush]::new($color)
    try { $graphics.FillPolygon($brush, $points) } finally { $brush.Dispose() }
}

function Stroke-Poly($graphics, [System.Drawing.PointF[]]$points, [System.Drawing.Color]$color, [single]$width = 1) {
    $pen = [System.Drawing.Pen]::new($color, $width)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    try { $graphics.DrawPolygon($pen, $points) } finally { $pen.Dispose() }
}

function Fill-Rect($graphics, [single]$x, [single]$y, [single]$width, [single]$height, [System.Drawing.Color]$color) {
    $brush = [System.Drawing.SolidBrush]::new($color)
    try { $graphics.FillRectangle($brush, $x, $y, $width, $height) } finally { $brush.Dispose() }
}

function Platform-Cells {
    $result = [System.Collections.Generic.List[object]]::new()
    for ($y = 0; $y -lt 14; $y++) {
        for ($x = 0; $x -lt 14; $x++) {
            if ((Symbol $x $y) -ne 'X') { $result.Add([pscustomobject]@{ X=$x; Y=$y; C=(Center $x $y) }) }
        }
    }
    return @($result | Sort-Object { $_.C.Y }, { $_.C.X })
}

function Cliff-Edges {
    $directions = @(
        @{ Name='UP'; DX=0; DY=-1; A=0; B=1 }, @{ Name='RIGHT'; DX=1; DY=0; A=1; B=2 },
        @{ Name='DOWN'; DX=0; DY=1; A=2; B=3 }, @{ Name='LEFT'; DX=-1; DY=0; A=3; B=0 }
    )
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($cell in (Platform-Cells)) {
        $diamond = Diamond $cell.X $cell.Y
        foreach ($direction in $directions) {
            if ((Symbol ($cell.X + $direction.DX) ($cell.Y + $direction.DY)) -eq 'X') {
                $a = $diamond[$direction.A]; $b = $diamond[$direction.B]
                $result.Add([pscustomobject]@{ Name=$direction.Name; A=$a; B=$b; Depth=(($a.Y+$b.Y)*0.5) })
            }
        }
    }
    return @($result | Sort-Object Depth)
}

function Connected-Groups([string]$target) {
    $remaining = [System.Collections.Generic.HashSet[string]]::new()
    for ($y=0; $y -lt 14; $y++) { for ($x=0; $x -lt 14; $x++) { if ((Symbol $x $y) -eq $target) { $null=$remaining.Add("$x,$y") } } }
    $groups = [System.Collections.Generic.List[object]]::new()
    while ($remaining.Count -gt 0) {
        $queue = [System.Collections.Generic.Queue[string]]::new()
        $group = [System.Collections.Generic.List[object]]::new()
        $seed = @($remaining)[0]; $queue.Enqueue($seed); $null=$remaining.Remove($seed)
        while ($queue.Count -gt 0) {
            $parts = $queue.Dequeue().Split(','); $cx=[int]$parts[0]; $cy=[int]$parts[1]
            $group.Add([pscustomobject]@{X=$cx;Y=$cy})
            foreach ($direction in @(@(0,-1),@(1,0),@(0,1),@(-1,0))) {
                $key="$($cx+$direction[0]),$($cy+$direction[1])"
                if ($remaining.Remove($key)) { $queue.Enqueue($key) }
            }
        }
        $groups.Add(@($group))
    }
    return @($groups)
}

function Convex-Hull([System.Drawing.PointF[]]$inputPoints) {
    $unique=@{}; foreach($p in $inputPoints){$unique["$($p.X),$($p.Y)"]=$p}; $points=@($unique.Values|Sort-Object X,Y)
    function Cross($o,$a,$b){return (($a.X-$o.X)*($b.Y-$o.Y))-(($a.Y-$o.Y)*($b.X-$o.X))}
    $lower=[System.Collections.Generic.List[System.Drawing.PointF]]::new()
    foreach($p in $points){while($lower.Count-ge 2-and(Cross $lower[$lower.Count-2] $lower[$lower.Count-1] $p)-le 0){$lower.RemoveAt($lower.Count-1)};$lower.Add($p)}
    $upper=[System.Collections.Generic.List[System.Drawing.PointF]]::new()
    for($i=$points.Count-1;$i-ge 0;$i--){$p=$points[$i];while($upper.Count-ge 2-and(Cross $upper[$upper.Count-2] $upper[$upper.Count-1] $p)-le 0){$upper.RemoveAt($upper.Count-1)};$upper.Add($p)}
    $lower.RemoveAt($lower.Count-1);$upper.RemoveAt($upper.Count-1)
    return [System.Drawing.PointF[]]@($lower.ToArray()+$upper.ToArray())
}

function Draw-Back($graphics,[bool]$heightGuide) {
    $ridge=if($heightGuide){Color '525252'}else{Color '7f8991'};$snow=if($heightGuide){Color '6b6b6b'}else{Color 'e2e7e9'}
    Fill-Poly $graphics ([System.Drawing.PointF[]]@(
        (Point 80 560),(Point 250 405),(Point 420 490),(Point 600 295),(Point 790 480),(Point 940 370),
        (Point 1120 500),(Point 1320 315),(Point 1510 470),(Point 1690 380),(Point 1968 570),(Point 1968 625),(Point 80 625))) $ridge
    Fill-Poly $graphics ([System.Drawing.PointF[]]@(
        (Point 105 558),(Point 250 430),(Point 420 510),(Point 600 330),(Point 790 510),(Point 940 405),
        (Point 1120 525),(Point 1320 350),(Point 1510 500),(Point 1690 415),(Point 1940 580),(Point 1940 622),(Point 105 622))) $snow
    Fill-Poly $graphics ([System.Drawing.PointF[]]@((Point 90 720),(Point 260 650),(Point 430 720),(Point 390 1010),(Point 180 1110),(Point 70 980))) $ridge
    Fill-Poly $graphics ([System.Drawing.PointF[]]@((Point 1958 720),(Point 1780 650),(Point 1615 735),(Point 1655 1030),(Point 1870 1110),(Point 1980 975))) $ridge
}

function Draw-Front($graphics,[bool]$heightGuide) {
    $rock=if($heightGuide){Color '424242'}else{Color '68737c'};$snow=if($heightGuide){Color '616161'}else{Color 'e7ebed'}
    Fill-Poly $graphics ([System.Drawing.PointF[]]@((Point 80 1290),(Point 255 1200),(Point 390 1305),(Point 320 1435),(Point 100 1455))) $rock
    Fill-Poly $graphics ([System.Drawing.PointF[]]@((Point 1968 1280),(Point 1780 1195),(Point 1650 1315),(Point 1735 1440),(Point 1950 1455))) $rock
    Fill-Poly $graphics ([System.Drawing.PointF[]]@((Point 92 1292),(Point 255 1220),(Point 370 1308),(Point 300 1360),(Point 120 1368))) $snow
    Fill-Poly $graphics ([System.Drawing.PointF[]]@((Point 1955 1285),(Point 1785 1218),(Point 1670 1318),(Point 1750 1365),(Point 1930 1370))) $snow
}

function Draw-Cliffs($graphics,[bool]$heightGuide) {
    foreach($edge in (Cliff-Edges)) {
        $shade=if($heightGuide){Color '2e2e2e'}elseif($edge.Name-in @('RIGHT','DOWN')){Color '4b555e'}else{Color '59646e'}
        $face=[System.Drawing.PointF[]]@($edge.A,$edge.B,(Point $edge.B.X ($edge.B.Y+$cliffDepth)),(Point $edge.A.X ($edge.A.Y+$cliffDepth)))
        Fill-Poly $graphics $face $shade
        if(-not $heightGuide){Stroke-Poly $graphics $face (Color '273039' 170) 1}
    }
}

function Draw-Ground($graphics,[string]$mode) {
    foreach($cell in (Platform-Cells)) {
        $symbol=Symbol $cell.X $cell.Y;$key="$($cell.X),$($cell.Y)"
        $shade=if($symbol-eq'~'){Color 'badde8'}elseif($roadCells.Contains($key)){Color 'c9c4bc'}else{Color 'edf1f3'}
        $diamond=Diamond $cell.X $cell.Y;Fill-Poly $graphics $diamond $shade
        if($symbol-eq'A'){Fill-Poly $graphics $diamond (Color '338ee8' 62)}
        if($symbol-eq'E'){Fill-Poly $graphics $diamond (Color 'dc5149' 62)}
        if($mode-ne'clean'){Stroke-Poly $graphics $diamond (Color '304656' 120) 1}
    }
}

function Draw-Obstacles($graphics,[bool]$heightGuide) {
    $described=[System.Collections.Generic.List[object]]::new()
    foreach($group in @((Connected-Groups '#')+(Connected-Groups 'R'))){$depth=-1;foreach($cell in $group){$depth=[Math]::Max($depth,(Center $cell.X $cell.Y).Y)};$described.Add([pscustomobject]@{Cells=$group;Depth=$depth})}
    foreach($entry in @($described|Sort-Object Depth)) {
        $group=$entry.Cells;$points=[System.Collections.Generic.List[System.Drawing.PointF]]::new();foreach($cell in $group){$points.AddRange([System.Drawing.PointF[]](Diamond $cell.X $cell.Y))}
        $base=Convex-Hull $points.ToArray();$landmark=(Symbol $group[0].X $group[0].Y)-eq'R';$height=if($landmark){$landmarkHeight}else{$obstacleHeight}
        $centerX=($base|Measure-Object X -Average).Average;$centerY=($base|Measure-Object Y -Average).Average
        $top=[System.Drawing.PointF[]]@($base|ForEach-Object{Point ($centerX+($_.X-$centerX)*0.78) ($centerY+($_.Y-$centerY)*0.78-$height)})
        $side=if($heightGuide){Color '404040'}elseif($landmark){Color '394148'}else{Color '444d55'}
        for($i=0;$i-lt$base.Count;$i++){$j=($i+1)%$base.Count;Fill-Poly $graphics ([System.Drawing.PointF[]]@($base[$i],$base[$j],$top[$j],$top[$i])) $side}
        $topShade=if($heightGuide){Color '858585'}elseif($landmark){Color '59636c'}else{Color '65717a'};Fill-Poly $graphics $top $topShade
        if(-not $heightGuide){Stroke-Poly $graphics $base (Color '283139' 220) 1.5;Stroke-Poly $graphics $top (Color 'e2ebef' 105) 1}
    }
}

function Draw-Mask($graphics) {
    $palette=@{'.'=Color 'd9e0e4';'~'=Color '78cde5';'#'=Color '48525b';'R'=Color '6d526f';'X'=Color '222a31';'A'=Color '338ee8';'E'=Color 'dc5149'}
    for($y=0;$y-lt14;$y++){for($x=0;$x-lt14;$x++){$diamond=Diamond $x $y;Fill-Poly $graphics $diamond $palette[(Symbol $x $y)];Stroke-Poly $graphics $diamond (Color '101820' 150) 1}}
}

function Draw-Debug($graphics) {
    $palette=@{'.'=Color 'd9e0e4' 74;'~'=Color '78cde5' 82;'#'=Color '48525b' 105;'R'=Color '6d526f' 115;'X'=Color '222a31' 175;'A'=Color '338ee8' 100;'E'=Color 'dc5149' 100}
    $font=[System.Drawing.Font]::new([System.Drawing.FontFamily]::GenericMonospace,9,[System.Drawing.FontStyle]::Bold,[System.Drawing.GraphicsUnit]::Pixel)
    $text=[System.Drawing.SolidBrush]::new((Color '17212a'));$dot=[System.Drawing.SolidBrush]::new((Color '17212a'))
    try {
        for($y=0;$y-lt14;$y++){for($x=0;$x-lt14;$x++){$symbol=Symbol $x $y;$diamond=Diamond $x $y;Fill-Poly $graphics $diamond $palette[$symbol];Stroke-Poly $graphics $diamond (Color '17212a' 145) 1;$center=Center $x $y;$graphics.FillEllipse($dot,$center.X-2.5,$center.Y-2.5,5,5);$graphics.DrawString("$x,$y $symbol",$font,$text,$center.X-22,$center.Y-16)}}
        $originBrush=[System.Drawing.SolidBrush]::new((Color 'ffcf4a'));try{$graphics.FillEllipse($originBrush,$origin[0]-7,$origin[1]-7,14,14)}finally{$originBrush.Dispose()};$graphics.DrawString('ORIGIN',$font,$text,$origin[0]+10,$origin[1]-10)
        $penX=[System.Drawing.Pen]::new((Color 'f09a37'),4);$penY=[System.Drawing.Pen]::new((Color '52b9ed'),4);try{$graphics.DrawLine($penX,$origin[0],$origin[1],$origin[0]+$axisX[0]*2,$origin[1]+$axisX[1]*2);$graphics.DrawLine($penY,$origin[0],$origin[1],$origin[0]+$axisY[0]*2,$origin[1]+$axisY[1]*2)}finally{$penX.Dispose();$penY.Dispose()}
        $cliffPen=[System.Drawing.Pen]::new((Color '17d7b8' 220),2);try{foreach($edge in (Cliff-Edges)){$graphics.DrawLine($cliffPen,$edge.A,$edge.B)}}finally{$cliffPen.Dispose()}
    } finally {$font.Dispose();$text.Dispose();$dot.Dispose()}
}

function New-Render([string]$mode) {
    $bitmap=[System.Drawing.Bitmap]::new(2048,2048,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$graphics=[System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias;$graphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality;$graphics.CompositingQuality=[System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    Fill-Rect $graphics 0 0 2048 2048 (Color 'd8dde2')
    if($mode-eq'mask'){Draw-Mask $graphics}elseif($mode-eq'height'){Fill-Rect $graphics 0 0 2048 2048 (Color 'ebebeb');Draw-Back $graphics $true;Draw-Cliffs $graphics $true;foreach($cell in (Platform-Cells)){Fill-Poly $graphics (Diamond $cell.X $cell.Y) (Color 'b8b8b8')};Draw-Obstacles $graphics $true;Draw-Front $graphics $true}else{Draw-Back $graphics $false;Draw-Cliffs $graphics $false;Draw-Ground $graphics $mode;Draw-Obstacles $graphics $false;Draw-Front $graphics $false;if($mode-eq'debug'){Draw-Debug $graphics}}
    $graphics.Dispose();return $bitmap
}

$exports=[ordered]@{'mountain_pass_blockout_reference.png'='reference';'mountain_pass_blockout_clean.png'='clean';'mountain_pass_blockout_debug.png'='debug';'mountain_pass_blockout_logic_mask.png'='mask';'mountain_pass_blockout_height_guide.png'='height'}
foreach($entry in $exports.GetEnumerator()){$bitmap=New-Render $entry.Value;$path=Join-Path $outputDir $entry.Key;try{$bitmap.Save($path,[System.Drawing.Imaging.ImageFormat]::Png)}finally{$bitmap.Dispose()};Write-Output "EXPORTED $($entry.Key) 2048x2048"}

$comparison=[System.Drawing.Bitmap]::new(2048,2048,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb);$cg=[System.Drawing.Graphics]::FromImage($comparison);$cg.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic;Fill-Rect $cg 0 0 2048 2048 (Color 'c7cdd2')
$names=@('mountain_pass_blockout_reference.png','mountain_pass_blockout_clean.png','mountain_pass_blockout_debug.png');$xs=@(32,704,1376)
for($i=0;$i-lt3;$i++){Fill-Rect $cg ($xs[$i]-5) 699 650 650 (Color '47535d');$panel=[System.Drawing.Image]::FromFile((Join-Path $outputDir $names[$i]));try{$cg.DrawImage($panel,[System.Drawing.RectangleF]::new($xs[$i],704,640,640))}finally{$panel.Dispose()}}
$cg.Dispose();$comparisonPath=Join-Path $outputDir 'mountain_pass_blockout_comparison.png';try{$comparison.Save($comparisonPath,[System.Drawing.Imaging.ImageFormat]::Png)}finally{$comparison.Dispose()};Write-Output 'EXPORTED mountain_pass_blockout_comparison.png 2048x2048'
