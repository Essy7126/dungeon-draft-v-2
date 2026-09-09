"""Assemble existing RGBA frames into a portable review. No artistic raster edits."""
import argparse
import base64
import html
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "artifacts/sprite_workshop/sentinelle_attack_pilot_2026-09-09"
LABELS = {"original": "Original", "a": "A · Retouches", "b": "B · Poses clés", "b_held": "B2 · Poses tenues"}
NOTES = {
    "original": "Identité de référence ; pointe peu dégagée à l’impact.",
    "a": "Contours plus propres ; corps redessiné malgré la demande locale.",
    "b": "Estoc plus lisible ; retour prématuré à l’ancienne pose en image 3.",
    "b_held": "Anticipation et retour tenus ; raccord au repos encore à travailler.",
}


def project_path(value):
    return ROOT / value.removeprefix("res://") if value.startswith("res://") else Path(value)


def uri(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    run_summary = json.loads((args.report.parent / "summary.json").read_text(encoding="utf-8-sig"))
    OUT.mkdir(parents=True, exist_ok=True)
    data, frames = {}, {}
    for key in LABELS:
        export = report["exports"][key]
        if not export["ok"]:
            raise ValueError(f"Incomplete export: {key}")
        directory = project_path(export["directory"])
        paths = [directory / "frames" / f"{i:03d}.png" for i in range(8)]
        images = [Image.open(p).convert("RGBA") for p in paths]
        if any(im.size != (512, 384) for im in images):
            raise ValueError("Unexpected frame dimensions")
        frames[key] = images
        data[key] = {"label": LABELS[key], "note": NOTES[key], "frames": [uri(p) for p in paths]}
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 19)
        small = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 14)
    except OSError:
        font = small = ImageFont.load_default()
    boards = []
    for index in range(8):
        board = Image.new("RGB", (1280, 500), "#171e28")
        draw = ImageDraw.Draw(board)
        draw.text((22, 14), "SENTINELLE · 4 variantes · 800 ms · release à 400 ms", font=font, fill="#eee4cd")
        for col, key in enumerate(LABELS):
            x = col * 320
            draw.line((x + 5, 283, x + 315, 283), fill="#384351")
            draw.text((x + 18, 50), LABELS[key], font=font, fill="#ebd2a1")
            large = frames[key][index].resize((410, 307), Image.Resampling.LANCZOS)
            # A deliberate canvas overlap in blank margins keeps the character centred.
            board.paste(large, (x - 15, 66), large)
            native = frames[key][index].resize((179, 134), Image.Resampling.LANCZOS)
            board.paste(native, (x + 77, 343), native)
            draw.text((x + 18, 320), "Taille de jeu : échelle 0,35", font=small, fill="#acb7c6")
        draw.text((22, 475), f"Image {index} · {index*100} ms" + (" · IMPACT" if index == 4 else "")
                  + "     Pilote visuel — non promu en production", font=small, fill="#eee4cd")
        boards.append(board)
    boards[0].save(OUT / "comparaison.gif", save_all=True, append_images=boards[1:],
                   duration=100, loop=0, optimize=False, disposal=2)
    boards[4].save(OUT / "comparaison_impact.png")
    strip = Image.new("RGB", (8*256, 4*225), "#171e28")
    draw = ImageDraw.Draw(strip)
    for row, key in enumerate(LABELS):
        for index, im in enumerate(frames[key]):
            thumb=im.resize((256,192),Image.Resampling.LANCZOS)
            strip.paste(thumb,(index*256,row*225+30),thumb)
            draw.text((index*256+8,row*225+7),f"{LABELS[key]} · {index}",font=small,fill="#eee4cd")
    strip.save(OUT / "poses_comparees.png")
    cards = "".join(f'<article><h2>{html.escape(LABELS[k])}</h2><canvas width="512" height="384" data-key="{k}"></canvas>'
                    f'<p>{html.escape(NOTES[k])}</p><div class="native"><canvas width="512" height="384" data-key="{k}"></canvas>'
                    '<span>Taille de jeu · × 0,35</span></div></article>' for k in LABELS)
    captures = []
    for key in LABELS:
        capture = args.report.parent / (key + "_attack.png")
        if capture.exists():
            captures.append(f'<figure><figcaption>{html.escape(LABELS[key])} · capture Godot 1280 × 720</figcaption>'
                            f'<img loading="lazy" src="{uri(capture)}"></figure>')
    summary = {
        "runtime_passed":run_summary["passed"],"runtime_checks":report["checks"],
        "errors":report["errors"]+run_summary.get("errors",[]),"visual_approval":False,
        "scope":report["scope"],"report":str(args.report.resolve()),
        "comparison_loop_ms":800,"png_frames":32,"generation_attempts":3,
    }
    (OUT / "review_manifest.json").write_text(json.dumps(summary,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    document = '''<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sentinelle — pilote rejeté, références à reprendre</title><style>
*{box-sizing:border-box}body{margin:0;background:#111822;color:#e4e7ed;font:16px/1.5 system-ui,sans-serif}main{max-width:1500px;margin:auto;padding:30px}
h1{font-size:30px;margin:4px 0 12px}h2{font-size:18px;color:#e6c895}p{color:#acb8c9}header{max-width:1000px}.eyebrow{font-size:12px;letter-spacing:.12em;color:#e6c895}
.controls{display:flex;align-items:center;gap:14px;flex-wrap:wrap;padding:18px;background:#202b39;border-radius:12px;margin:24px 0}
button,select{padding:10px 15px;border:1px solid #5d7086;border-radius:7px;background:#263649;color:white;font:inherit;cursor:pointer}input{accent-color:#edb75f}
.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}article{border:1px solid #344254;background:#192431;border-radius:12px;padding:15px;overflow:hidden}
canvas{width:100%;height:auto;background:linear-gradient(0deg,#223246,#223246);border-radius:6px}article p{min-height:72px;font-size:14px}
.native{height:178px;display:flex;align-items:center;flex-direction:column}.native canvas{width:179.2px;height:134.4px;background:transparent}.native span{font-size:12px;color:#acb8c9}
.time{color:#ffd280;font-variant-numeric:tabular-nums}aside{padding:18px;border-left:3px solid #dfad65;background:#252d38;margin-top:24px}
figure{margin:26px 0}figure img{width:100%;max-width:1280px;border-radius:10px}figcaption{padding:8px;color:#e6c895}details{margin-top:28px}pre{white-space:pre-wrap;font-size:13px}
@media(max-width:950px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:520px){.grid{grid-template-columns:1fr}main{padding:14px}}
</style><main><header><div class="eyebrow">ATELIER SPRITES · ESSAI DU 9 SEPTEMBRE 2026</div><h1>Un estoc plus lisible. Des raccords encore visibles.</h1>
<p>Original, retouches et nouvelles poses, tous à huit images de 100 ms. Le release reste à 400 ms. B2 tient les poses aux images 2–3 et 5–6. Les sources de production sont conservées.</p></header>
<div class="controls"><button id="play">Pause</button><button id="previous" aria-label="Image précédente">←</button><button id="next" aria-label="Image suivante">→</button>
<label>Image <input id="scrub" type="range" min="0" max="7" value="0"></label><span id="time" class="time"></span>
<label>Vitesse <select id="speed"><option value="0.25">× 0,25</option><option value="0.5">× 0,5</option><option value="1" selected>× 1</option></select></label></div>
<section class="grid">__CARDS__</section><aside><strong>Revue utilisateur : les variantes sont rejetées pour la production.</strong> L’arme gagne en lisibilité, mais le mouvement du buste, de la tête et des appuis manque de coordination ; les directions restent insuffisamment définies. B2 corrige le montage sans résoudre ces défauts. Reprendre depuis une référence de mouvement et des poses complètes simplifiées avant tout nouveau dessin final.</aside>
<p>La lecture boucle directement les huit images (800 ms). Dans le jeu, une attaque s’exécute une seule fois puis revient à l’idle.</p>
<details><summary>Contrôles techniques et périmètre</summary><pre>__SUMMARY__</pre></details>
<details><summary>Voir les captures du combat Godot</summary>__CAPTURES__</details></main>
<script>const clips=__DATA__;const cache={};let playing=true,index=0,speed=1,last=performance.now(),elapsed=0;
const scrub=document.querySelector('#scrub'),time=document.querySelector('#time'),play=document.querySelector('#play');
function draw(){document.querySelectorAll('canvas').forEach(c=>{const ctx=c.getContext('2d');ctx.clearRect(0,0,512,384);ctx.drawImage(cache[c.dataset.key][index],0,0)});scrub.value=index;time.textContent=`${index} / 7 · ${index*100} ms${index===4?' · IMPACT':''}`;document.body.dataset.frame=index;}
function pause(){playing=false;play.textContent='Lecture'}play.onclick=()=>{playing=!playing;play.textContent=playing?'Pause':'Lecture';elapsed=0};
document.querySelector('#previous').onclick=()=>{pause();index=(index+7)%8;draw()};document.querySelector('#next').onclick=()=>{pause();index=(index+1)%8;draw()};
scrub.oninput=()=>{pause();index=Number(scrub.value);draw()};document.querySelector('#speed').onchange=e=>{speed=Number(e.target.value);elapsed=0};
function tick(now){if(playing){elapsed+=(now-last)*speed;if(elapsed>=100){index=(index+Math.floor(elapsed/100))%8;elapsed%=100;draw()}}last=now;requestAnimationFrame(tick)}
Promise.all(Object.keys(clips).map(async key=>{cache[key]=await Promise.all(clips[key].frames.map(src=>new Promise(resolve=>{const im=new Image();im.onload=()=>resolve(im);im.src=src}))) })).then(()=>{draw();last=performance.now();requestAnimationFrame(tick)});
</script></html>'''
    document = document.replace("__CARDS__",cards).replace("__SUMMARY__",html.escape(json.dumps(summary,indent=2,ensure_ascii=False)))
    document = document.replace("__CAPTURES__","".join(captures)).replace("__DATA__",json.dumps(data,ensure_ascii=False))
    (OUT / "comparaison.html").write_text(document,encoding="utf-8")
    print(json.dumps({"review":str(OUT / "comparaison.html"),"gif":str(OUT / "comparaison.gif"),**summary},ensure_ascii=False))


if __name__ == "__main__":
    main()
