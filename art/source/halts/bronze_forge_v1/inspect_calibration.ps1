$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
$manifest = Get-Content -LiteralPath (Join-Path $root 'data/halts/bronze_forge_v1.json') -Raw | ConvertFrom-Json
$source = [System.Drawing.Bitmap]::new((Join-Path $root 'asset/map/painted/halts/bronze_forge_v1/forge.png'))
$graphics = [System.Drawing.Graphics]::FromImage($source)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
function Convert-Points($points) {
    [System.Drawing.PointF[]]@($points | ForEach-Object { [System.Drawing.PointF]::new($_[0] * $source.Width, $_[1] * $source.Height) })
}
$green = [System.Drawing.Pen]::new([System.Drawing.Color]::Lime, 3)
$red = [System.Drawing.Pen]::new([System.Drawing.Color]::OrangeRed, 3)
$blue = [System.Drawing.Pen]::new([System.Drawing.Color]::DeepSkyBlue, 2)
$graphics.DrawPolygon($green, [System.Drawing.PointF[]](Convert-Points $manifest.navigation.outline))
foreach ($poly in $manifest.navigation.obstacles) { $graphics.DrawPolygon($red, [System.Drawing.PointF[]](Convert-Points $poly)) }
foreach ($fg in $manifest.foreground) { $graphics.DrawPolygon($blue, [System.Drawing.PointF[]](Convert-Points $fg.polygon)) }
foreach ($item in $manifest.landmarks) {
    $x = $item.point[0] * $source.Width
    $y = $item.point[1] * $source.Height
    $graphics.FillEllipse([System.Drawing.Brushes]::Lime, $x-9, $y-9, 18, 18)
    $graphics.DrawString($item.id, [System.Drawing.SystemFonts]::DefaultFont, [System.Drawing.Brushes]::White, $x+12, $y)
}
foreach ($torch in $manifest.torches) {
    $x = $torch.point[0] * $source.Width
    $y = $torch.point[1] * $source.Height
    $graphics.DrawEllipse($red, $x-6, $y-6, 12, 12)
}
$source.Save((Join-Path $PSScriptRoot 'calibration_review.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$source.Dispose()
$green.Dispose()
$red.Dispose()
$blue.Dispose()
