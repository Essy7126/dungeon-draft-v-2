$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$sourcePath = Join-Path $taskRoot 'docs/design/achilles/ankama_character_feasibility_2026-09-12.md'
$outputDirectory = Join-Path $taskRoot 'artifacts/spine_trial/ankama_character_production'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$body = (ConvertFrom-Markdown -Path $sourcePath).Html
$title = [regex]::Match($body, '<h1[^>]*>(.*?)</h1>').Groups[1].Value
$body = $body.Replace('ankama_character_pipeline_2026-09-12.md', 'v1/review.html')
$body = $body.Replace('../../../artifacts/spine_trial/', '/files/')
$referenceDirectory = Join-Path $outputDirectory 'references'
New-Item -ItemType Directory -Path $referenceDirectory -Force | Out-Null
$referenceManifest = [System.Collections.Generic.List[object]]::new()
foreach ($match in [regex]::Matches($body, '(?:href|src)="([^"]+)"')) {
    $target = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    if ($target -match '^(https?://|#|/|data:|v1/)') { continue }
    $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path $sourcePath) $target))
    if (-not $resolved.StartsWith($taskRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Référence hors du projet : $target" }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Référence absente : $target" }
    $relative = [IO.Path]::GetRelativePath($taskRoot, $resolved).Replace('\', '/')
    $name = $relative.Replace('/', '_') + '.txt'
    Copy-Item -LiteralPath $resolved -Destination (Join-Path $referenceDirectory $name) -Force
    $body = $body.Replace($match.Groups[1].Value, 'references/' + $name)
    $referenceManifest.Add([pscustomobject]@{ Source = $relative; Copy = 'references/' + $name; Sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash })
}
$referenceManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDirectory 'reference_manifest.json') -Encoding utf8NoBOM
$toc = [System.Collections.Generic.List[string]]::new()
$chapterNumber = 0
foreach ($chapter in [regex]::Matches($body, '<h2[^>]*>(.*?)</h2>')) {
    $chapterNumber++
    $label = [regex]::Replace($chapter.Groups[1].Value, '^\d+\.\s*', '')
    $body = $body.Replace($chapter.Value, "<h2 id=`"chapitre-$chapterNumber`">$($chapter.Groups[1].Value)</h2>")
    $toc.Add("<li><a href=`"#chapitre-$chapterNumber`"><span>$chapterNumber</span>$label</a></li>")
}
$calculator = @'
<form class="calculator" id="memory-form">
  <fieldset><legend>Explorer le coût des images complètes</legend>
  <p>Comparaison théorique à 4 octets par pixel. Toutes les animations sont supposées avoir le même nombre d’images par vue dans cet exemple.</p>
  <div class="inputs">
    <label>Largeur (px)<input name="width" type="number" min="1" max="8192" value="384" required></label>
    <label>Hauteur (px)<input name="height" type="number" min="1" max="8192" value="384" required></label>
    <label>Images par vue<input name="frames" type="number" min="1" max="600" value="24" required></label>
    <label>Directions<input name="directions" type="number" min="1" max="32" value="4" required></label>
    <label>Animations<input name="animations" type="number" min="1" max="100" value="1" required></label>
  </div>
  <output id="memory-result" aria-live="polite">54 Mio de pixels non compressés · 96 images</output>
  <p class="small">Ce total n’est ni la taille des fichiers PNG ni la mémoire mesurée dans Godot. Il exclut compression, découpe, réutilisation de pièces, chargement partiel, marges d’atlas et mipmaps.</p>
  </fieldset>
</form>
'@
$example = [regex]::Match($body, '<p>Exemple de dimensionnement,[\s\S]*?</p>')
if (-not $example.Success) { throw 'Le paragraphe de dimensionnement est absent.' }
$body = $body.Replace($example.Value, $example.Value + $calculator)
$body = [regex]::Replace($body, '(<table>[\s\S]*?</table>)', '<div class="table-scroll" tabindex="0">$1</div>')
$template = @'
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Choix du style, audit des capacités réelles et pipeline progressive pour les personnages de Catabase, à partir des méthodes d’Ankama, Klei, Motion Twin et Red Hook.">
<title>__TITLE__</title>
<style>
:root{--ink:#202321;--muted:#616762;--line:#d9ded9;--accent:#176342;--paper:#fff;--surface:#f5f7f5}
*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:30px}body{margin:0;background:var(--paper);color:var(--ink);font:17px/1.7 system-ui,-apple-system,"Segoe UI",sans-serif}a{color:var(--accent);text-underline-offset:3px}a:hover{text-decoration-thickness:2px}a:focus-visible,button:focus-visible,input:focus-visible,summary:focus-visible{outline:3px solid var(--accent);outline-offset:4px}.skip{position:fixed;left:20px;top:-80px;padding:8px;background:white;z-index:10}.skip:focus{top:10px}.layout{display:grid;grid-template-columns:285px minmax(0,1fr);max-width:1460px;margin:auto}aside{position:sticky;top:0;height:100vh;overflow-y:auto;border-right:1px solid var(--line);padding:32px 24px;font-size:13px;line-height:1.45}aside .home{display:block;color:var(--ink);font-size:16px;font-weight:650;text-decoration:none;margin-bottom:24px}details summary{font-size:14px;font-weight:650;cursor:pointer;margin:8px 0 16px}nav ol{padding:0;list-style:none;margin:0}nav li{margin:0 0 10px}nav a{display:grid;grid-template-columns:24px 1fr;color:var(--muted);text-decoration:none;padding:3px 0}nav a:hover,nav a[aria-current="location"]{color:var(--accent)}nav a[aria-current="location"]{font-weight:650}nav span{font-variant-numeric:tabular-nums;color:#858b85}.actions{border-top:1px solid var(--line);margin-top:26px;padding-top:18px;display:flex;gap:16px;flex-wrap:wrap}.actions button{font:inherit;border:0;padding:0;background:transparent;color:var(--accent);text-decoration:underline;text-underline-offset:3px;cursor:pointer}main{min-width:0;padding:66px clamp(28px,6vw,90px) 100px}article{max-width:800px;margin:0 auto}h1{font-size:clamp(32px,4vw,48px);line-height:1.15;letter-spacing:-1.7px;font-weight:650;max-width:730px;margin:0 0 32px}h2{font-size:27px;line-height:1.3;letter-spacing:-.5px;font-weight:650;border-top:1px solid var(--line);padding-top:34px;margin:58px 0 22px;scroll-margin-top:25px}h3{font-size:20px;line-height:1.4;margin:34px 0 12px}p{margin:0 0 19px}strong{font-weight:650}ul,ol{padding-left:24px}li{padding-left:3px;margin:9px 0}code{font-size:.88em;overflow-wrap:anywhere;background:var(--surface);padding:1px 4px}.table-scroll{overflow-x:auto;margin:26px 0;border-bottom:1px solid var(--line)}table{border-collapse:collapse;width:100%;font-size:14px;line-height:1.55;min-width:570px}th{text-align:left;font-weight:650;background:var(--surface)}th,td{vertical-align:top;padding:13px 14px;border-top:1px solid var(--line)}th:first-child,td:first-child{padding-left:10px}td:first-child{font-weight:550;min-width:130px}table a{white-space:normal}article>h2:last-of-type~ol{font-size:14px;line-height:1.65}article>h2:last-of-type~ol>li{margin-bottom:17px}fieldset{border:1px solid var(--line);margin:30px 0;padding:20px;min-width:0}legend{font-size:16px;font-weight:650;padding:0 7px}.calculator p{font-size:14px;color:var(--muted)}.inputs{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin:14px 0 22px}label{font-size:13px;display:block}input{width:100%;display:block;font:inherit;font-size:16px;color:var(--ink);border:1px solid #a6b1a8;border-radius:3px;margin-top:5px;padding:8px;background:#fff}output{display:block;font-size:21px;color:var(--accent);font-weight:650;line-height:1.4}.calculator .small{font-size:12px;margin:12px 0 0}footer{border-top:1px solid var(--line);padding-top:18px;margin-top:50px;font-size:13px;color:var(--muted)}
@media(max-width:850px){.layout{display:block}aside{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line);padding:20px 24px}aside .home{margin:0 0 10px;font-size:14px}details summary{margin:8px 0}nav ol{columns:2;column-gap:24px}nav li{break-inside:avoid}aside .actions{border:0;margin:10px 0 0;padding:0}main{padding:36px 24px 70px}h1{letter-spacing:-1px}h2{font-size:24px;margin-top:42px;padding-top:26px}}
@media(max-width:480px){body{font-size:16px;line-height:1.65}nav ol{columns:1}main{padding-left:20px;padding-right:20px}h1{font-size:34px}.inputs{grid-template-columns:repeat(2,minmax(0,1fr))}fieldset{padding:14px}output{font-size:19px}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}
article img{display:block;max-width:100%;height:auto;margin:24px auto}article p:has(>img){margin:30px 0}
@media print{aside,.skip,.calculator{display:none}.layout{display:block}main{padding:0}article{max-width:none;font-size:11pt}h1{font-size:26pt}h2{font-size:18pt;break-after:avoid}h3{break-after:avoid}table{min-width:0;font-size:9pt}tr{break-inside:avoid}a{color:inherit}footer{font-size:9pt}}
</style>
</head>
<body>
<a class="skip" href="#contenu">Aller au dossier</a>
<div class="layout">
<aside aria-label="Navigation du dossier">
  <a class="home" href="#contenu">Dossier de production</a>
  <details id="contents" open><summary>Sommaire · __CHAPTERS__ chapitres</summary><nav aria-label="Chapitres"><ol>__TOC__</ol></nav></details>
  <div class="actions"><a href="dossier.md" download>Télécharger</a><button type="button" id="print">Imprimer</button></div>
</aside>
<main id="contenu"><article>__BODY__
</article></main>
</div>
<script>
const form=document.getElementById('memory-form');
const result=document.getElementById('memory-result');
function updateMemory(){
 const values=['width','height','frames','directions','animations'].map(name=>Number(form.elements[name].value));
 if(!form.checkValidity()){result.textContent='Renseigner des valeurs entières dans les limites indiquées.';return;}
 const [width,height,frames,directions,animations]=values;
 const count=frames*directions*animations;
 const mib=width*height*count*4/1048576;
 result.textContent=new Intl.NumberFormat('fr-FR',{maximumFractionDigits:2}).format(mib)+' Mio de pixels non compressés · '+new Intl.NumberFormat('fr-FR').format(count)+' images';
}
form.addEventListener('input',updateMemory);form.addEventListener('submit',event=>event.preventDefault());updateMemory();
document.getElementById('print').addEventListener('click',()=>window.print());
const contents=document.getElementById('contents');
if(matchMedia('(max-width:850px)').matches)contents.open=false;
const navLinks=[...document.querySelectorAll('nav a')];
navLinks.forEach(link=>link.addEventListener('click',()=>{if(matchMedia('(max-width:850px)').matches)contents.open=false;}));
const chapterObserver=new IntersectionObserver(entries=>{
 for(const entry of entries){if(entry.isIntersecting){navLinks.forEach(link=>{if(link.hash==='#'+entry.target.id)link.setAttribute('aria-current','location');else link.removeAttribute('aria-current');});}}
},{rootMargin:'-10% 0px -70% 0px',threshold:0});
document.querySelectorAll('article h2').forEach(heading=>chapterObserver.observe(heading));
</script>
</body></html>
'@
$html = $template.Replace('__TOC__', ($toc -join "`n")).Replace('__BODY__', $body).Replace('__TITLE__', $title).Replace('__CHAPTERS__', [string]$chapterNumber)
[IO.File]::WriteAllText((Join-Path $outputDirectory 'review.html'), $html, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $outputDirectory 'dossier.md') -Force
[PSCustomObject]@{ Output = (Join-Path $outputDirectory 'review.html'); Chapters = $chapterNumber; Bytes = [Text.Encoding]::UTF8.GetByteCount($html) } | ConvertTo-Json
