$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$planPath = Join-Path $PSScriptRoot 'spatial_plan.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
$canvas = [System.Drawing.Bitmap]::new(1600, 900)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#142735'))
function Convert-Points($items) {
    [System.Drawing.PointF[]]@($items | ForEach-Object { [System.Drawing.PointF]::new($_[0] * 1600, $_[1] * 900) })
}
$floorBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#526566'))
$graphics.FillPolygon($floorBrush, (Convert-Points $plan.walkable_outline))
$islandBrush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#573f2f'))
$graphics.FillPolygon($islandBrush, (Convert-Points $plan.central_obstacle))
$routePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#e9c96c'), 13)
$routePen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
$graphics.DrawLines($routePen, [System.Drawing.PointF[]](Convert-Points $plan.route))
$font = [System.Drawing.Font]::new('Arial', 25, [System.Drawing.FontStyle]::Bold)
$smallFont = [System.Drawing.Font]::new('Arial', 17)
$white = [System.Drawing.Brushes]::White
$graphics.DrawString('SPATIAL PLAN - DRY ROOTS FORGE', $font, $white, 44, 32)
$graphics.DrawString('Same elevated 3/4 camera. Broad stone loop. No water. No people.', $smallFont, $white, 44, 86)
$graphics.DrawString('LOW ANVIL ISLAND', $smallFont, $white, 655, 515)
$graphics.DrawString('ENTRANCE', $font, $white, 135, 770)
foreach ($landmark in $plan.landmarks) {
    $x = $landmark.object[0] * 1600
    $y = $landmark.object[1] * 900
    $graphics.FillRectangle($islandBrush, $x - 90, $y - 60, 180, 90)
    $graphics.DrawString($landmark.id.ToUpper(), $font, $white, $x - 78, $y - 50)
    $approachX = $landmark.point[0] * 1600
    $approachY = $landmark.point[1] * 900
    $graphics.FillEllipse([System.Drawing.Brushes]::PaleGreen, $approachX - 12, $approachY - 12, 24, 24)
}
$graphics.DrawString('Floor / broad route = gray. Route = amber. Solid objects = brown.', $smallFont, $white, 570, 845)
$canvas.Save((Join-Path $PSScriptRoot 'spatial_plan.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$canvas.Dispose()
$font.Dispose()
$smallFont.Dispose()
$floorBrush.Dispose()
$islandBrush.Dispose()
$routePen.Dispose()
