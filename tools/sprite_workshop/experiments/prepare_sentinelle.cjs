'use strict';
// Mechanical preparation only: existing matte, uniform cohort scale and foot placement.
// Artistic source drawings are kept verbatim alongside their imagegen prompts.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');
const {matteBackground, connectedComponents} = require('../../achilles_polish_v3_pipeline/matting.cjs');
const root = path.resolve(__dirname, '../../..');
const relative = 'art/source/sprite_workshop/sentinelle_attack_pilot_2026-09-09';
const source = path.join(root, relative);
const out = path.join(root, 'artifacts/sprite_workshop/sentinelle_attack_pilot_2026-09-09');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const write = (p, value) => fs.writeFileSync(p, JSON.stringify(value, null, 2) + '\n');

async function main() {
  fs.mkdirSync(out, {recursive:true});
  const baseline = JSON.parse(fs.readFileSync(path.join(root, 'art/source/sprite_workshop/sentinelle_attack_e.json')));
  const cohorts = [
    {id:'a', file:'variant_a_source.png', scale:0.455,
      key:{mode:'checker', minimum:95, chroma:14, blue_bias:-8, hole_dark_max:180, hole_light_min:200}},
    {id:'b', file:'variant_b_corrected_source.png', scale:0.515,
      key:{mode:'magenta', edge_despill:{radius:2, minimum_excess:12}}}
  ];
  const report = {operation:'mechanical matte, uniform scale and foreground-foot registration',
    target_canvas:[512,384], logical_anchor:[256,320], foreground_foot_target:[270,320],
    preserved_duration_ms:800, release_frame:4, release_ms:400, replaced_indices:[2,4,5],
    source_generation:{tool:'built-in imagegen', attempts:3, tokens:null,
      limitation:'All generated sources are RGB. A contains a painted checkerboard; B was regenerated on magenta.'},
    cohorts:[], variants:[]};
  for (const cfg of cohorts) {
    const inputPath = path.join(source, cfg.file);
    const {data,info} = await sharp(inputPath).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    if (info.width!==2172 || info.height!==724) throw Error('Unexpected source sheet geometry');
    const matte = matteBackground(data, info.width, info.height, cfg.key);
    await sharp(matte.data,{raw:{width:info.width,height:info.height,channels:4}})
      .png().toFile(path.join(out, cfg.id+'_matte.png'));
    const cohort = {id:cfg.id, source:cfg.file, sha256:hash(inputPath), scale:cfg.scale,
      key:cfg.key, matte:matte.report, frames:[]};
    const replacements = [];
    const bodies=connectedComponents(matte.data,info.width,info.height,16).components
      .filter(c=>c.count>10000).sort((a,b)=>a.center[0]-b.center[0]);
    if(bodies.length!==3)throw Error('Expected three separate complete poses');
    const cuts=[0,...[0,1].map(i=>Math.floor((bodies[i].bbox[2]+bodies[i+1].bbox[0])/2)),info.width];
    for (let i=0;i<3;i++) {
      const width=cuts[i+1]-cuts[i];
      const cropped = await sharp(matte.data,{raw:{width:info.width,height:info.height,channels:4}})
        .extract({left:cuts[i],top:0,width,height:724}).raw().toBuffer();
      // No connected components are dropped: detached parts remain visible for review.
      const cc = connectedComponents(cropped,width,724,1);
      const comps = cc.components.filter(c=>c.count>=10);
      const bbox = [width,724,0,0];
      for(const c of cc.components) {
        bbox[0]=Math.min(bbox[0],c.bbox[0]); bbox[1]=Math.min(bbox[1],c.bbox[1]);
        bbox[2]=Math.max(bbox[2],c.bbox[2]); bbox[3]=Math.max(bbox[3],c.bbox[3]);
      }
      let sum=0,count=0;
      for(let y=bbox[3]-10;y<bbox[3];y++)for(let x=0;x<width;x++) {
        if(cropped[(y*width+x)*4+3]>=128){sum+=x;count++;}
      }
      if(!count)throw Error('No foreground foot found');
      const foot=[sum/count,bbox[3]-1];
      const cropWidth=bbox[2]-bbox[0],cropHeight=bbox[3]-bbox[1];
      const scaledWidth=Math.round(cropWidth*cfg.scale),scaledHeight=Math.round(cropHeight*cfg.scale);
      const left=Math.round(270-(foot[0]-bbox[0])*cfg.scale), top=Math.round(320-(foot[1]-bbox[1])*cfg.scale);
      if(left<0||top<0||left+scaledWidth>512||top+scaledHeight>384)throw Error('Canvas would clip foreground');
      const resized=await sharp(cropped,{raw:{width,height:724,channels:4}})
        .extract({left:bbox[0],top:bbox[1],width:cropWidth,height:cropHeight})
        .resize(scaledWidth,scaledHeight,{kernel:'lanczos3',fit:'fill'}).png().toBuffer();
      const name=`${cfg.id}_pose_${i}.png`, framePath=path.join(source,name);
      await sharp({create:{width:512,height:384,channels:4,background:{r:0,g:0,b:0,alpha:0}}})
        .composite([{input:resized,left,top}]).png().toFile(framePath);
      cohort.frames.push({index:i,source_cell:[cuts[i],0,width,724],bbox,foot,scale:cfg.scale,
        rounded_size:[scaledWidth,scaledHeight],translation:[left,top],components:comps,
        source_border_occupied:bbox[0]===0||bbox[2]===width});
      replacements.push({source:'res://'+relative+'/'+name,sha256:hash(framePath),
        region:[0,0,512,384],placement:[0,0],offset:[0,0]});
    }
    report.cohorts.push(cohort);
    const doc=structuredClone(baseline);
    doc.id='sentinelle_attack_e_'+(cfg.id==='a'?'retouch':'keyposes');
    doc.title=cfg.id==='a'?'A · Retouches demandées, corps redessiné':'B · Nouvelles poses clés';
    doc.intent='Pilote contrôlé : remplacer seulement f002, f004 et f005, garder durée et release.';
    doc.review={};
    doc.open_questions=['Qualité artistique non approuvée. Vérifier les raccords avec les poses conservées et les appuis.',
      cfg.id==='a'?'La retouche générative ne conserve pas exactement les pixels du corps.':'L’anticipation levée et le retour doivent être évalués en mouvement.'];
    [2,4,5].forEach((index,i)=>Object.assign(doc.frames[index],replacements[i]));
    doc.provenance['res://'+relative+'/'+cfg.file]=hash(inputPath);
    const docPath=path.join(source,'variant_'+cfg.id+'.json');
    write(docPath,doc); report.variants.push('res://'+relative+'/variant_'+cfg.id+'.json');
    if(cfg.id==='b') {
      const assembled=structuredClone(doc);
      assembled.id='sentinelle_attack_e_keyposes_held';
      assembled.title='B2 · Poses clés tenues';
      assembled.intent='Essai distinct après B : tenir anticipation f002–f003 et retour f005–f006. Même release et durée.';
      Object.assign(assembled.frames[3],replacements[0]);
      Object.assign(assembled.frames[6],replacements[2]);
      assembled.open_questions.push('Les poses tenues évitent deux retours prématurés, sans créer de dessin intermédiaire.');
      write(path.join(source,'variant_b_held.json'),assembled);
      report.variants.push('res://'+relative+'/variant_b_held.json');
    }
  }
  write(path.join(out,'preparation.json'),report);
  console.log(JSON.stringify({report:path.join(out,'preparation.json'),cohorts:report.cohorts.map(c=>({id:c.id,
    removed:c.matte.removed_pixels,frames:c.frames.map(f=>({bbox:f.bbox,translation:f.translation,border:f.source_border_occupied}))})),variants:report.variants}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
