"""Build a local review of the actual exported atlas regions."""
from pathlib import Path
import argparse
import json
import math
from PIL import Image, ImageDraw, ImageFont
from build import ACTION_FRAMES, restore_frame, profile_durations

ROOT = Path(__file__).resolve().parents[2]
FAMILIES = [
    ('sentinelle_airain', "Sentinelle d’airain", 'Défenseur lourd · 2 PM'),
    ('rejeton_braise', 'Rejeton de braise', 'Artilleur incendiaire · 3 PM'),
    ('molosse_styx', 'Molosse du Styx', 'Prédateur mobile · 5 PM'),
    ('lamie_lethe', 'Lamie du Léthé', 'Contrôle du terrain · 3 PM'),
]


def write_html_review():
    """Self-contained controls and embedded geometry; local PNGs need no fetch."""
    destination = ROOT / 'output/catabase_monsters_v2/review'
    destination.mkdir(parents=True, exist_ok=True)
    families = []
    for slug, name, role in FAMILIES:
        directory = ROOT / 'assets/characters/catabase_monsters' / slug
        directions = {}
        for direction in 'NESW':
            manifest = json.loads((directory / f'atlas_{direction}.manifest.json').read_text(encoding='utf-8'))
            if len(manifest['frames']) != 48:
                raise ValueError(f'{slug}/{direction}: the HTML review requires all 48 poses')
            directions[direction] = {
                'url': f'../../../assets/characters/catabase_monsters/{slug}/atlas_{direction}.png',
                'frames': [{'region': frame['region'], 'crop': frame['crop']}
                           for frame in manifest['frames']],
            }
        families.append({'slug': slug, 'name': name, 'role': role,
                         'durations': profile_durations(slug), 'directions': directions,
                         'gameScale': .29 if slug == 'rejeton_braise' else .35})
    payload = json.dumps({'families': families, 'actions': ACTION_FRAMES}, ensure_ascii=False).replace('<', '\\u003c')
    html = '''<!doctype html>
<html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Monstres de Catabase · animations</title>
<style>
:root{color-scheme:dark;font:16px system-ui,sans-serif;background:#142126;color:#e8e6dd}body{max-width:1000px;margin:32px auto;padding:0 20px}h1{font-size:26px;margin:0 0 8px}.muted{color:#b2c3c8}label{display:grid;gap:6px;font-size:14px}.controls{display:flex;flex-wrap:wrap;gap:14px;margin:24px 0 16px}select,button,input{font:inherit}select,button{border:1px solid #52656b;background:#26383f;color:inherit;border-radius:8px;padding:9px 12px}button{cursor:pointer}button:hover{background:#344c54}.stage{border:1px solid #43575e;border-radius:14px;background:radial-gradient(ellipse at center,#2d4149,#1c2c33);height:440px;display:grid;place-items:center;overflow:hidden}canvas{display:block;max-width:100%;height:auto}.timeline{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:16px;margin:18px 0}input{width:100%}output{font-variant-numeric:tabular-nums;min-width:90px;text-align:right}.meta{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;font-size:14px}#error{color:#ffbdac;white-space:pre-wrap}footer{font-size:13px;line-height:1.5;margin-top:25px}
</style>
<h1>Monstres de Catabase</h1><div class="muted">Inspecter les poses réellement exportées dans le jeu.</div>
<div class="controls">
<label>Personnage<select id="family"></select></label>
<label>Direction<select id="direction"><option>N</option><option selected>E</option><option>S</option><option>W</option></select></label>
<label>Animation<select id="action"><option value="idle">Repos</option><option value="walk">Marche</option><option value="attack">Attaque</option><option value="cast">Sort / technique</option><option value="hit">Coup reçu</option><option value="death">Mort</option></select></label>
<label>Échelle<select id="zoom"><option value="game">Taille jeu</option><option value="double">2 × taille jeu</option><option value="source" selected>Pixels source</option></select></label>
</div>
<div class="stage"><canvas id="canvas" width="512" height="384" aria-label="Animation du monstre sélectionné"></canvas></div>
<div class="timeline"><button id="play" type="button">Pause</button><input id="frame" aria-label="Pose dans l’animation" type="range" min="0" max="7" value="0" step="1"><output id="counter">1 / 8</output></div>
<div class="meta"><span id="role"></span><span id="timing"></span><span id="release"></span></div>
<p id="error" role="status"></p><footer class="muted">Les quatre directions sont peintes séparément. Les mouvements utilisent une articulation locale en 2D à partir de ces vues fixes. Les attaques et les morts sont répétées ici pour faciliter la revue ; dans le combat, elles se jouent une seule fois. Les PV varient selon la salle. La croix indique l’ancre logique au sol.</footer>
<script id="data" type="application/json">__DATA__</script>
<script>
const data=JSON.parse(document.querySelector('#data').textContent);
const ids=['family','direction','action','zoom','play','frame','counter','role','timing','release','error','canvas'];
const ui=Object.fromEntries(ids.map(id=>[id,document.getElementById(id)]));
const ctx=ui.canvas.getContext('2d'), images=new Map();
let playing=true, elapsed=0, last=0;
data.families.forEach((family,index)=>ui.family.add(new Option(family.name,index)));
function selected(){return data.families[Number(ui.family.value)];}
function indices(){return data.actions[ui.action.value];}
function currentImage(){const item=selected().directions[ui.direction.value];if(!images.has(item.url)){const image=new Image();image.onload=draw;image.onerror=()=>{ui.error.textContent='Atlas absent : '+item.url;};image.src=item.url;images.set(item.url,image);}return images.get(item.url);}
function draw(){
 const family=selected(),action=ui.action.value,poses=indices(),index=Number(ui.frame.value);
 const geometry=family.directions[ui.direction.value].frames[poses[index]],image=currentImage();
 const scale=ui.zoom.value==='source'?1:family.gameScale*(ui.zoom.value==='double'?2:1);
 ctx.clearRect(0,0,512,384);ctx.save();ctx.translate(256,320);ctx.scale(scale,scale);ctx.translate(-256,-320);
 ctx.strokeStyle='#628991';ctx.lineWidth=1/scale;ctx.beginPath();ctx.moveTo(246,320);ctx.lineTo(266,320);ctx.moveTo(256,315);ctx.lineTo(256,325);ctx.stroke();
 if(image.complete&&image.naturalWidth){const [x,y,w,h]=geometry.region;ctx.drawImage(image,x,y,w,h,geometry.crop[0],geometry.crop[1],w,h);}ctx.restore();
 ui.counter.value=(index+1)+' / '+poses.length;ui.role.textContent=family.role;
 const duration=family.durations[action];ui.timing.textContent=duration.toLocaleString('fr-FR',{maximumFractionDigits:2})+' s · '+(poses.length/duration).toLocaleString('fr-FR',{maximumFractionDigits:1})+' poses/s';
 ui.release.textContent=['attack','cast'].includes(action)?'Libération : pose 5 / 8'+(index===4?' · maintenant':''):'';
}
function reset(){elapsed=0;ui.frame.max=indices().length-1;ui.frame.value=0;ui.error.textContent='';draw();}
ui.family.onchange=reset;ui.direction.onchange=draw;ui.action.onchange=reset;ui.zoom.onchange=draw;
ui.play.onclick=()=>{playing=!playing;ui.play.textContent=playing?'Pause':'Lire';};
ui.frame.oninput=()=>{playing=false;ui.play.textContent='Lire';elapsed=Number(ui.frame.value)/indices().length*selected().durations[ui.action.value];draw();};
document.addEventListener('visibilitychange',()=>{last=0;});
function tick(now){if(last&&playing){const duration=selected().durations[ui.action.value];elapsed=(elapsed+(now-last)/1000)%duration;ui.frame.value=Math.min(indices().length-1,Math.floor(elapsed/duration*indices().length));draw();}last=now;requestAnimationFrame(tick);}
reset();requestAnimationFrame(tick);
</script></html>'''
    path = destination / 'animation_review.html'
    path.write_text(html.replace('__DATA__', payload), encoding='utf-8')
    print(path)
    return path


def main():
    destination = ROOT / 'output/catabase_monsters/review'
    destination.mkdir(parents=True, exist_ok=True)
    font_root = Path('C:/Windows/Fonts')
    title = ImageFont.truetype(str(font_root / 'segoeuib.ttf'), 24)
    subtitle = ImageFont.truetype(str(font_root / 'segoeui.ttf'), 17)
    sprites = []
    for slug, _, _ in FAMILIES:
        directory = ROOT / 'assets/characters/catabase_monsters' / slug
        atlas = Image.open(directory / 'atlas_E.png').convert('RGBA')
        manifest = json.loads((directory / 'atlas_E.manifest.json').read_text(encoding='utf-8'))
        sprites.append([restore_frame(atlas, frame) for frame in manifest['frames']])
    labels = {'idle': 'Respiration', 'walk': 'Marche', 'attack': 'Attaque',
              'cast': 'Sort / technique spéciale', 'hit': 'Impact reçu', 'death': 'Mort'}
    durations = [profile_durations(slug) for slug, _, _ in FAMILIES]
    steps = []
    # One shared real-time sampling clock lets each creature keep its own breath,
    # stride and action duration, rather than forcing all families onto one pose.
    for action in ['idle', 'walk', 'attack', 'cast', 'hit', 'death']:
        duration = max(item[action] for item in durations) * (2 if action in ['idle', 'walk'] else 1)
        steps += [(action, sample / 20.0, 50) for sample in range(math.ceil(duration * 20))]
    steps.append(('death', max(item['death'] for item in durations), 1000))
    frames = []
    for action, elapsed, _ in steps:
        canvas = Image.new('RGB', (1024, 800), '#152126')
        draw = ImageDraw.Draw(canvas)
        for k, (_, name, stats) in enumerate(FAMILIES):
            x, y = (k % 2) * 512, (k // 2) * 400
            draw.rounded_rectangle((x + 8, y + 8, x + 504, y + 392), radius=18, fill='#27363d')
            draw.text((x + 24, y + 21), name, font=title, fill='#ead6ad')
            draw.text((x + 24, y + 54), stats, font=subtitle, fill='#b3c6ca')
            phase = elapsed / durations[k][action]
            if action in ['idle', 'walk']:
                phase %= 1.0
            indices = ACTION_FRAMES[action]
            index = indices[min(len(indices) - 1, int(phase * len(indices)))]
            sprite = sprites[k][index]
            sprite = sprite.resize((450, 338), Image.Resampling.LANCZOS)
            canvas.paste(sprite, (x + 31, y + 60), sprite)
            draw.text((x + 24, y + 362), labels[action], font=subtitle, fill='#e4be73')
        if not frames:
            canvas.save(destination / 'monstres_apercu.png')
        frames.append(canvas.quantize(colors=256, method=Image.Quantize.MEDIANCUT))
    frames[0].save(destination / 'monstres_animations.gif', save_all=True, append_images=frames[1:], duration=[duration for _, _, duration in steps], loop=0, optimize=False, disposal=2)
    print(destination / 'monstres_animations.gif')
    write_html_review()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--html-only', action='store_true')
    options = parser.parse_args()
    write_html_review() if options.html_only else main()
