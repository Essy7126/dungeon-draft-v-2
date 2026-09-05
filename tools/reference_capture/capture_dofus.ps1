param(
    [string]$OutputPath = ""
)
$ErrorActionPreference = "Stop"
$useDefaultOutput = [string]::IsNullOrWhiteSpace($OutputPath)
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $projectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $OutputPath = Join-Path $projectRoot ("artifacts/reference_capture/dofus_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".png")
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
New-Item -ItemType Directory -Path (Split-Path $OutputPath -Parent) -Force | Out-Null
if ($useDefaultOutput) {
    [IO.File]::WriteAllText((Join-Path (Split-Path $OutputPath -Parent) ".gdignore"), "")
}
Add-Type -AssemblyName System.Drawing
if (-not ("DofusReferenceCapture" -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DofusReferenceCapture {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out RECT rect);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr window, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
}
[DofusReferenceCapture]::SetProcessDPIAware() | Out-Null
$candidates = @(Get-Process -Name Dofus -ErrorAction Stop | Where-Object { $_.MainWindowHandle -ne 0 })
if ($candidates.Count -ne 1) {
    throw "Expected exactly one open Dofus window; found $($candidates.Count)."
}
$target = $candidates[0]
if ([DofusReferenceCapture]::IsIconic($target.MainWindowHandle)) {
    throw "Dofus is minimized. Restore its window before capturing."
}
$bounds = [DofusReferenceCapture+RECT]::new()
if (-not [DofusReferenceCapture]::GetWindowRect($target.MainWindowHandle, [ref]$bounds)) {
    throw "Cannot read Dofus window bounds."
}
$width = $bounds.Right - $bounds.Left
$height = $bounds.Bottom - $bounds.Top
if ($width -le 0 -or $height -le 0 -or $width -gt 8000 -or $height -gt 8000) {
    throw "Unexpected capture dimensions: $width x $height."
}
$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $hdc = $graphics.GetHdc()
    try {
        $captured = [DofusReferenceCapture]::PrintWindow($target.MainWindowHandle, $hdc, 2)
    } finally {
        $graphics.ReleaseHdc($hdc)
    }
    if (-not $captured) { throw "PrintWindow could not capture Dofus." }
    $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}
$metadata = [ordered]@{
    method = "Win32 PrintWindow PW_RENDERFULLCONTENT"
    captured_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    process_id = $target.Id
    width = $width
    height = $height
    image = $OutputPath
    sha256 = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash
    input_sent = $false
    game_settings_changed = $false
    caveat = "A successful API call does not guarantee useful pixels; inspect the image."
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath ([System.IO.Path]::ChangeExtension($OutputPath, ".json")) -Encoding utf8
$metadata | ConvertTo-Json
