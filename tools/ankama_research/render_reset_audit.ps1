$ErrorActionPreference = 'Stop'
$taskRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$source = Join-Path $taskRoot 'docs/design/achilles/animation_reset_2026-09-12.md'
$output = Join-Path $taskRoot 'artifacts/spine_trial/animation_reset'
$html = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'reset_review.html') -Raw
$body = (ConvertFrom-Markdown -Path $source).Html
$body = $body.Replace('../../../artifacts/spine_trial/', '/files/')
New-Item -ItemType Directory -Force -Path (Join-Path $output 'evidence') | Out-Null
foreach ($match in [regex]::Matches($body, '(?:href|src)="([^"]+)"')) {
    $target = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    if ($target -match '^(https?://|#|/)') { continue }
    $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path $source) $target))
    if (-not $resolved.StartsWith($taskRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Reference outside project' }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Missing reference: $target" }
    $name = [IO.Path]::GetRelativePath($taskRoot, $resolved).Replace('\','_').Replace('/','_') + '.txt'
    Copy-Item -LiteralPath $resolved -Destination (Join-Path $output ('evidence/' + $name)) -Force
    $body = $body.Replace($match.Groups[1].Value, 'evidence/' + $name)
}
$style = [regex]::Match($html, '<style>([\s\S]*?)</style>').Value
$page = '<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Diagnostic complet</title>' + $style + '<main><a href="review.html">Retour au comparatif</a>' + $body + '</main></html>'
Set-Content -LiteralPath (Join-Path $output 'audit.html') -Value $page
Write-Output 'Audit rendered; local references resolved.'
