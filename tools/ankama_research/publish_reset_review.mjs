// Publish an evidence review from existing files. No animation is regenerated.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const out=path.join(root,'artifacts/spine_trial/animation_reset');
const read=p=>fs.readFileSync(path.join(root,p));
const json=p=>JSON.parse(read(p));
fs.mkdirSync(path.join(out,'reference'),{recursive:true});
for(let i=0;i<16;i++){const f='frame_'+String(i).padStart(2,'0')+'.png';fs.copyFileSync(path.join(root,'artifacts/dev/veilleur-nicolas-study',f),path.join(out,'reference',f));}
const metadata='artifacts/spine_trial/veilleur_walk_iso_v1/walk_review.json';
const motion='artifacts/spine_trial/veilleur_walk_iso_v1/E_motion.json';
const d=json(metadata),m=json(motion),scale=d.display_scale;
const range=v=>Math.max(...v)-Math.min(...v);
const stride=Math.hypot(...d.views.E.stride)*scale;
const inputs=[metadata,motion,'tools/veilleur_walk/build_iso.py','tools/veilleur_walk/walk_v5_refined.py','artifacts/dev/veilleur-nicolas-study/source.json'];
const report={date:'2026-09-12',artistic_decision:'rejected_by_user',scope:'Diagnostic of existing E motion, not a new artistic validation or a population gait norm',frames:m.length,cycle_ms:d.duration*1000,display_scale:scale,root_excursion_game_px:[0,1].map(a=>range(m.map(f=>f.root[a]))*scale),body_angle_range_radians:range(m.map(f=>f.body_angle)),stride_game_px:stride,speed_game_px_per_s:stride/d.duration,steps_per_s:2/d.duration,source_reference:json('artifacts/dev/veilleur-nicolas-study/source.json'),inputs:inputs.map(p=>({path:p,sha256:crypto.createHash('sha256').update(read(p)).digest('hex')}))};
fs.writeFileSync(path.join(out,'diagnostic_metrics.json'),JSON.stringify(report,null,2)+'\n');
fs.copyFileSync(path.join(root,'tools/ankama_research/reset_review.html'),path.join(out,'review.html'));
fs.copyFileSync(path.join(root,'docs/design/achilles/animation_reset_2026-09-12.md'),path.join(out,'audit.md'));
// Add a visible decision to the source and published legacy review; retain all media and test reports.
for(const folder of ['art/source/characters/achilles/veilleur_walk_iso_v1','artifacts/spine_trial/veilleur_walk_iso_v1']){
 const p=path.join(root,folder,'review.html');let html=fs.readFileSync(p,'utf8');
 if(!html.includes('id="artistic-rejection"')){html=html.replace('<main>','<main><aside id="artistic-rejection" class="note"><p><strong>Essai rejeté artistiquement le 12 septembre 2026.</strong> Le personnage est jugé mécanique et sans vie. <a href="http://127.0.0.1:8734/files/animation_reset/review.html">Voir le diagnostic et la reprise de méthode.</a></p></aside>');fs.writeFileSync(p,html);}
 fs.writeFileSync(path.join(root,folder,'artistic_decision.json'),JSON.stringify({date:'2026-09-12',status:'rejected_by_user',reason:'Mouvement mécanique et personnage sans vie ; reprise de la méthode demandée.',audit:'docs/design/achilles/animation_reset_2026-09-12.md',historical_technical_reports_unchanged:true},null,2)+'\n');
}
console.log(JSON.stringify({review:path.join(out,'review.html'),metrics:report},null,2));
