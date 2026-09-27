"""Review unmodified Godot viewport captures; never rewrites character assets."""
import json,sys
from pathlib import Path
from PIL import Image

root=Path(sys.argv[1])
samples=json.loads((root/'locomotion_samples.json').read_text(encoding='utf-8'))
states=[{'trial':s['trial'],'animation':s['state']['animation'],'frame':s['state']['frame'],'facing':s['state']['facing'],'landing':s['state']['landing_pending'],'ms':s.get('captured_ms',0)} for s in samples]
frames=sorted((root/'frames').glob('*.png'))
assert len(frames)==len(states),(len(frames),len(states))
html='''<!doctype html><meta charset="utf-8"><title>Passe-Rive · vérification S22</title>
<style>body{background:#20282b;color:#e4e4d5;font:16px system-ui;margin:32px auto;max-width:1000px}#frame{width:720px;max-width:100%}button,select{font:inherit;padding:8px;margin-right:10px}input{width:720px;max-width:100%}p{color:#bcc7ba}details img{width:100%}</style>
<h1>Passe-Rive · marche, sorts et ruée</h1><p>Captures natives Godot, échantillonnées environ 12 fois par seconde ; temps de capture conservés. Le décor est conservé pour examiner les appuis et l’arrivée.</p>
<div><button id="play">Pause</button><select id="trial"></select></div><p id="info"></p><img id="frame"><br><input id="scrub" type="range" min="0">
<details><summary>Comparaisons de taille · départ, contact, retour</summary>'''
for d in ['E','SE','S','NE','N']:html+=f'<p>{d}</p><img src="scale_{d}.png">'
html+='</details><script>const samples='+json.dumps(states,separators=(',',':'))+''';const groups={};samples.forEach((s,i)=>(groups[s.trial]??=[]).push(i));const sel=document.querySelector('#trial'),img=document.querySelector('#frame'),scrub=document.querySelector('#scrub');for(const k of Object.keys(groups))sel.add(new Option(k,k));let n=0,playing=true;function draw(){const a=groups[sel.value],i=a[n%a.length],s=samples[i];img.src='frames/'+String(i).padStart(4,'0')+'.png';scrub.max=a.length-1;scrub.value=n;document.querySelector('#info').textContent=s.trial+' · '+s.animation+' · pose '+s.frame+(s.landing?' · réception':'')}sel.onchange=()=>{n=0;draw()};scrub.oninput=()=>{playing=false;n=+scrub.value;draw()};document.querySelector('#play').onclick=()=>{playing=!playing;document.querySelector('#play').textContent=playing?'Pause':'Lire'};function tick(){const a=groups[sel.value],i=n,j=(n+1)%a.length;const dt=j>i?samples[a[j]].ms-samples[a[i]].ms:90;setTimeout(()=>{if(playing){n=(n+1)%groups[sel.value].length;draw()}tick()},Math.max(20,Math.min(300,dt||90)))}tick();sel.value='SE_1';draw();</script>'''
(root/'review.html').write_text(html,encoding='utf-8')
for trial in ['SE_1','SE_3','r_shot','a_sweep','dash_SE','dash_NE']:
 indexes=[i for i,s in enumerate(states) if s['trial']==trial]
 if not indexes:continue
 images=[Image.open(frames[i]).convert('RGB') for i in indexes]
 images[0].save(root/(trial+'.gif'),save_all=True,append_images=images[1:],duration=[max(20,min(300,states[indexes[i+1]]['ms']-states[indexes[i]]['ms'])) if i+1<len(indexes) else 90 for i in range(len(images))],loop=0,optimize=False)
 print(trial,len(images))
print(root/'review.html')
