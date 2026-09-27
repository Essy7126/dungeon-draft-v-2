"""Assemble diagnostic Godot captures. Never rewrites character source assets."""
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path

from PIL import Image


def build(source: Path, output: Path) -> None:
    report = json.loads((source / "report.json").read_text(encoding="utf-8-sig"))
    if not report["passed"]:
        raise ValueError("A successful native Godot capture is required")
    rooms = json.loads((source / "rooms.json").read_text(encoding="utf-8-sig"))
    frames = sorted(source.glob("transition_*.png"))
    if len(frames) != 75:
        raise ValueError(f"Expected 75 transition captures, found {len(frames)}")
    output.mkdir(parents=True, exist_ok=True)
    # Crop empty diagnostic backdrop only. A shared GIF palette prevents
    # frame-dependent quantization from introducing artificial color flicker.
    crops = [Image.open(path).convert("RGB").crop((0, 30, 1440, 350)) for path in frames]
    sample = Image.new("RGB", (1440, 320 * 15))
    for i, frame in enumerate(crops[::5]):
        sample.paste(frame, (0, i * 320))
    palette = sample.quantize(colors=256, dither=Image.Dither.NONE)
    indexed = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in crops]
    indexed[0].save(output / "transitions.gif", save_all=True, append_images=indexed[1:],
                    duration=[30, 30, 40] * 25, loop=0, optimize=False, disposal=2)

    def url(path: Path) -> str:
        return Path(os.path.relpath(path, output)).as_posix()

    data = {
        "frames": [url(p) for p in frames],
        "boards": {d: url(source / f"scale_{d}.png") for d in ("SE", "E", "S", "NE", "N")},
        "rooms": [{"label": p.stem.removeprefix("room_"), "src": url(p)}
                  for p in sorted(source.glob("room_*.png"))],
    }
    rows = "".join(f"<tr><td>{html.escape(row['room'])}</td><td>{row['height']:.6f} px</td></tr>"
                   for row in rooms)
    page = """<!doctype html><html lang="fr"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Passe-Rive · cohérence S23</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#182124;color:#e7e9de;font:16px/1.5 system-ui}main{max-width:1488px;padding:24px;margin:auto}h1{font-size:30px;margin:0}h2{font-size:21px;margin:28px 0 10px}p{max-width:1000px}small{color:#b1c4bb}button,select{font:inherit;background:#303f43;color:inherit;border:1px solid #788e81;padding:8px 14px;border-radius:6px}input{width:min(650px,70vw)}.controls{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin:12px 0}img{max-width:100%;display:block}.strip{width:100%;aspect-ratio:1440/350;overflow:hidden;background:#303b3e}.strip img{width:100%;max-width:none}figure{margin:0}.note{border-left:3px solid #b49961;padding:10px 18px;background:#252e2f}table{border-collapse:collapse;font-size:14px}td{padding:5px 14px 5px 0;border-bottom:1px solid #354449}a{color:#aed3bd}
</style><main>
<small>CAPTURES GODOT · 26 SEPTEMBRE 2026 · S23</small>
<h1>Passe-Rive — taille et palette communes</h1>
<p>Sept gestes conservés, marche native conservée. Cette revue montre les vrais rendus du moteur, avec une correction fixe par atlas et une référence commune entre les salles.</p>
<div class="note"><strong>Limite visible :</strong> certains dessins d’attaque restent plus larges ou construisent la capuche différemment du repos. Les couleurs et l’échelle ne suffisent pas à effacer cette différence. Aucun fondu entre deux silhouettes ne la masque.</div>
<h2>Repos → action → repos</h2>
<p><small>Vue SE agrandie pour inspecter les raccords. 75 captures à 30 images/s ; ni interpolation inventée, ni filtre supplémentaire.</small></p>
<div class="controls"><button id="play">Pause</button><input id="scrub" type="range" min="0" max="74" value="0"><output id="time"></output></div>
<div class="strip"><img id="frame" alt="Sept animations, même instant"></div>
<h2>Départ, contact, retour</h2>
<div class="controls"><label>Direction <select id="angle"><option>SE</option><option>E</option><option>S</option><option>NE</option><option>N</option></select></label></div>
<img id="board" alt="Repos et sept attaques aux trois temps clés">
<h2>Comparaison des salles</h2>
<p>Stature de référence de 90 pixels dans cette fenêtre 1440 × 950, à zoom initial. Le zoom volontaire continue à agrandir toute la scène.</p>
<div class="controls"><select id="room"></select></div><img id="roomImage" alt="Passe-Rive dans la salle sélectionnée">
<details><summary>Mesures des 17 scènes</summary><table>__ROWS__</table></details>
<p><a href="__REPORT__">Rapport moteur</a> · <a href="transitions.gif">Animation GIF</a></p>
</main><script>
const data=__DATA__;
const frames=data.frames.map(src=>{const im=new Image();im.src=src;return im});
const frame=document.getElementById('frame'), scrub=document.getElementById('scrub'), time=document.getElementById('time'), play=document.getElementById('play');
let index=0, playing=true, last=performance.now();
function show(){frame.src=data.frames[index];scrub.value=index;time.value=`${index+1}/75 · ${(index/30).toFixed(2)} s`}
play.onclick=()=>{playing=!playing;play.textContent=playing?'Pause':'Lecture';last=performance.now()};
scrub.oninput=()=>{index=Number(scrub.value);playing=false;play.textContent='Lecture';show()};
function tick(now){if(playing&&now-last>=1000/30){const step=Math.floor((now-last)/(1000/30));index=(index+step)%75;last+=step*1000/30;show()}requestAnimationFrame(tick)}
const angle=document.getElementById('angle'),board=document.getElementById('board');angle.onchange=()=>board.src=data.boards[angle.value];angle.onchange();
const room=document.getElementById('room'),roomImage=document.getElementById('roomImage');data.rooms.forEach((r,i)=>{const o=document.createElement('option');o.value=i;o.textContent=r.label;room.appendChild(o)});room.onchange=()=>roomImage.src=data.rooms[room.value].src;room.onchange();show();requestAnimationFrame(tick);
</script></html>"""
    page = page.replace("__ROWS__", rows).replace("__REPORT__", html.escape(url(source / "report.json")))
    page = page.replace("__DATA__", json.dumps(data, ensure_ascii=False))
    (output / "review.html").write_text(page, encoding="utf-8")
    (output / "provenance.json").write_text(json.dumps({"source": str(source), "frames": len(frames),
        "rooms": len(rooms), "checks": len(report["checks"]), "passed": report["passed"]}, indent=2), encoding="utf-8")
    print(json.dumps({"review": str(output / "review.html"), "gif": str(output / "transitions.gif")}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve())
