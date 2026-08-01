param(
    [string]$CaptureDirectory = "artifacts\skill_tree_refined_v2\captures",
    [string]$BeforeCapture = "artifacts\skill_tree_refined\captures\skill_tree_before_1920x1080.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$captureRoot = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $CaptureDirectory))
$beforePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $BeforeCapture))
$afterPath = Join-Path $captureRoot "refined_after_1920x1080.png"

function New-Canvas([int]$width, [int]$height) {
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 8, 11, 15))
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    return @($bitmap, $graphics)
}

function Save-Grayscale([string]$sourcePath, [string]$outputPath) {
    $source = [System.Drawing.Image]::FromFile($sourcePath)
    $canvas = New-Canvas $source.Width $source.Height
    $bitmap = $canvas[0]
    $graphics = $canvas[1]
    $attributes = New-Object System.Drawing.Imaging.ImageAttributes
    $matrix = New-Object System.Drawing.Imaging.ColorMatrix
    $matrix.Matrix00 = 0.299
    $matrix.Matrix01 = 0.299
    $matrix.Matrix02 = 0.299
    $matrix.Matrix10 = 0.587
    $matrix.Matrix11 = 0.587
    $matrix.Matrix12 = 0.587
    $matrix.Matrix20 = 0.114
    $matrix.Matrix21 = 0.114
    $matrix.Matrix22 = 0.114
    $matrix.Matrix33 = 1.0
    $matrix.Matrix44 = 1.0
    $attributes.SetColorMatrix($matrix)
    $destination = New-Object System.Drawing.Rectangle 0, 0, $source.Width, $source.Height
    $graphics.DrawImage($source, $destination, 0, 0, $source.Width, $source.Height, [System.Drawing.GraphicsUnit]::Pixel, $attributes)
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $attributes.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    $source.Dispose()
}

function Save-BlurredReduced([string]$sourcePath, [string]$outputPath) {
    $source = [System.Drawing.Image]::FromFile($sourcePath)
    $smallCanvas = New-Canvas 320 180
    $small = $smallCanvas[0]
    $smallGraphics = $smallCanvas[1]
    $smallGraphics.DrawImage($source, 0, 0, 320, 180)
    $outputCanvas = New-Canvas 640 360
    $output = $outputCanvas[0]
    $outputGraphics = $outputCanvas[1]
    $outputGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $outputGraphics.DrawImage($small, 0, 0, 640, 360)
    $output.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $outputGraphics.Dispose()
    $output.Dispose()
    $smallGraphics.Dispose()
    $small.Dispose()
    $source.Dispose()
}

function Draw-FittedImage($graphics, $image, [System.Drawing.RectangleF]$target) {
    $scale = [Math]::Min($target.Width / $image.Width, $target.Height / $image.Height)
    $width = [float]($image.Width * $scale)
    $height = [float]($image.Height * $scale)
    $x = [float]($target.X + (($target.Width - $width) / 2.0))
    $y = [float]($target.Y + (($target.Height - $height) / 2.0))
    $graphics.DrawImage($image, $x, $y, $width, $height)
}

function Save-BeforeAfter([string]$before, [string]$after, [string]$outputPath) {
    $beforeImage = [System.Drawing.Image]::FromFile($before)
    $afterImage = [System.Drawing.Image]::FromFile($after)
    $canvas = New-Canvas 1920 594
    $bitmap = $canvas[0]
    $graphics = $canvas[1]
    $font = New-Object System.Drawing.Font "Segoe UI", 18, ([System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 230, 203, 113))
    $graphics.DrawString("AVANT", $font, $brush, 20, 12)
    $graphics.DrawString("APRES - REFINED V2", $font, $brush, 980, 12)
    Draw-FittedImage $graphics $beforeImage (New-Object System.Drawing.RectangleF 0, 54, 960, 540)
    Draw-FittedImage $graphics $afterImage (New-Object System.Drawing.RectangleF 960, 54, 960, 540)
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
    $beforeImage.Dispose()
    $afterImage.Dispose()
}

function Save-ContactSheet([string[]]$sourceNames, [string[]]$labels, [string]$outputPath) {
    $canvas = New-Canvas 1600 980
    $bitmap = $canvas[0]
    $graphics = $canvas[1]
    $font = New-Object System.Drawing.Font "Segoe UI", 16, ([System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 226, 226, 219))
    for ($index = 0; $index -lt $sourceNames.Count; $index++) {
        $column = $index % 2
        $row = [Math]::Floor($index / 2)
        $x = 20 + ($column * 790)
        $y = 20 + ($row * 480)
        $graphics.DrawString($labels[$index], $font, $brush, $x, $y)
        $image = [System.Drawing.Image]::FromFile((Join-Path $captureRoot $sourceNames[$index]))
        Draw-FittedImage $graphics $image (New-Object System.Drawing.RectangleF $x, ($y + 36), 760, 420)
        $image.Dispose()
    }
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $brush.Dispose()
    $font.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

Save-Grayscale $afterPath (Join-Path $captureRoot "refined_after_grayscale.png")
Save-BlurredReduced $afterPath (Join-Path $captureRoot "refined_after_blurred_reduced.png")
Save-BeforeAfter $beforePath $afterPath (Join-Path $captureRoot "before_after_comparison.png")
Save-ContactSheet @(
    "lock_closeup.png",
    "node_types_contact_sheet.png",
    "branch_navigation.png",
    "node_detail_panel.png"
) @(
    "VERROU ET MASQUAGE",
    "TYPES DE NODES",
    "NAVIGATION DE BRANCHES",
    "PANNEAU DE DETAIL"
) (Join-Path $captureRoot "components_contact_sheet.png")

Write-Host "Review captures generated in $captureRoot"
