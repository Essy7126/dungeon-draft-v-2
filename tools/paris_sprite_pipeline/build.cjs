#!/usr/bin/env node
'use strict';
// Only mechanical extraction/alignment/packing of native ImageGen RGBA artwork.
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
let sharp; try { sharp = require('sharp'); } catch { sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); }
const {segmentSource, maskedFramePixels} = require('./segmentation.cjs');
const ROOT = path.resolve(__dirname, '../..');
const SRC = 'art/source/characters/paris/sprites_v1', OUT = 'assets/characters/paris/sprites_v1';
const DIRS = ['E','N','S','W'], MASTERS = ['E','N'], FORMS = ['spectral','infernal'];
const MASTER_FOR = {E:'E',N:'N',S:'E',W:'N'};
const RUNTIME_DIRECTIONS = Object.fromEntries(DIRS.map(direction=>[direction,{master:MASTER_FOR[direction],flip_h:direction==='S'||direction==='W'}]));
const frameCount = key => key==='transform_ALL'?8:16;
const W = 512, H = 384, PIVOT = [256,320], COLS = 4;
const CLIPS = {
  idle: {frames:[0], duration:1, loop:true}, walk:{frames:[1,2,3,4], duration:0.72, loop:true},
  attack:{frames:[5,6,7,8],duration:0.68,release:0.34}, cast:{frames:[9,10,11],duration:0.76,release:0.38},
  hit:{frames:[12,13],duration:0.24}, death:{frames:[14,15],duration:0.64}
};
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const abs = p => path.join(ROOT,p);
function alphaStats(data) { let zero=0,opaque=0,max=0; for(let i=3;i<data.length;i+=4){zero+=data[i]===0;opaque+=data[i]===255;max=Math.max(max,data[i]);} return {zero,opaque,max,transparent_fraction:zero/(data.length/4)}; }
function bounds(data,width,height,threshold=24) { const b=[width,height,0,0];let count=0,border=0;for(let y=0;y<height;y++)for(let x=0;x<width;x++){if(data[(y*width+x)*4+3]<=threshold)continue;count++;if(!x||!y||x===width-1||y===height-1)border++; b[0]=Math.min(b[0],x);b[1]=Math.min(b[1],y);b[2]=Math.max(b[2],x+1);b[3]=Math.max(b[3],y+1);} return {bbox:b,count,border}; }
function windows(width,height,count=16) {if(![8,16].includes(count))throw Error('Expected 8 or 16 source windows');const rows=count/4;return Array.from({length:count},(_,i)=>{const l=Math.round(i%4*width/4),t=Math.round(Math.floor(i/4)*height/rows);return [l,t,Math.round((i%4+1)*width/4)-l,Math.round((Math.floor(i/4)+1)*height/rows)-t];});}
function validateWindows(key,layout,data,width,height) {
  if(!Array.isArray(layout)||layout.length!==frameCount(key))throw Error(key+': exactly '+frameCount(key)+' source windows required');
  const coverage=new Uint8Array(width*height);
  for(let index=0;index<layout.length;index++) {
    const window=layout[index];
    if(!Array.isArray(window)||window.length!==4||!window.every(Number.isInteger))throw Error(key+'/'+index+': window requires four integers');
    const [left,top,w,h]=window;
    if(left<0||top<0||w<=0||h<=0||left+w>width||top+h>height)throw Error(key+'/'+index+': window outside source bounds');
    for(let y=top;y<top+h;y++)for(let x=left;x<left+w;x++)coverage[y*width+x]++;
  }
  let nonzero=0,omitted=0,duplicated=0;
  for(let index=0;index<coverage.length;index++) {
    if(data[index*4+3]===0)continue;
    nonzero++;
    if(coverage[index]===0)omitted++;
    else if(coverage[index]!==1)duplicated++;
  }
  if(omitted||duplicated)throw Error(key+': source windows omit '+omitted+' and duplicate '+duplicated+' nonzero-alpha pixels');
  return {nonzero_source_pixels:nonzero,omitted_nonzero_pixels:omitted,duplicated_nonzero_pixels:duplicated};
}
function clipFrames(key,name,clip,count,overrides={}) {
  const frames=Object.prototype.hasOwnProperty.call(overrides,key+':'+name)?overrides[key+':'+name]:clip.frames;
  if(!Array.isArray(frames)||frames.length!==clip.frames.length||frames.some(i=>!Number.isInteger(i)||i<0||i>=count)) {
    throw Error('Invalid clip frames '+key+':'+name+'; expected '+clip.frames.length+' valid texture references');
  }
  return frames;
}
async function inspect(key,alignment={}) {
  const source=`${SRC}/source_${key}.png`, bytes=fs.readFileSync(abs(source));
  const meta=await sharp(bytes).metadata(); const {data,info}=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const alpha=alphaStats(data);
  if(!meta.hasAlpha||alpha.transparent_fraction<0.35)throw Error(`${key}: source has no usable native transparency (${alpha.transparent_fraction})`);
  if(alignment.segmentation!==undefined && typeof alignment.segmentation!=='boolean')throw Error(key+': segmentation must be an explicit boolean');
  const segmented=alignment.segmentation===true?segmentSource(data,info.width,info.height,frameCount(key)):null;
  const layout=segmented?segmented.layout:alignment.windows||windows(info.width,info.height,frameCount(key));
  const coverage=segmented?segmented.coverage:validateWindows(key,layout,data,info.width,info.height);
  const cells=[];for(let i=0;i<layout.length;i++){
    const [left,top,width,height]=layout[i];
    const pixels=segmented?maskedFramePixels(data,segmented.labels,info.width,layout[i],i)
      :await sharp(bytes).extract({left,top,width,height}).ensureAlpha().raw().toBuffer();
    const b=bounds(pixels,width,height);
    cells.push({index:i,window:layout[i],...b,preserved_rgba_sha256:hash(pixels),suggested_root:[left+(b.bbox[0]+b.bbox[2])/2,top+b.bbox[3]]});
  }
  const result={key,source,source_sha256:hash(bytes),dimensions:[info.width,info.height],alpha,
    extraction_mode:segmented?'segmentation':'windows',source_window_coverage:coverage,cells,bytes};
  if(segmented){
    result.segmentation=segmented.summary;
    // Keep ownership masks out of JSON manifests and --inspect output. They
    // are mechanical working memory, recomputed from the SHA-bound source.
    Object.defineProperty(result,'_segmentedPixels',{value:{data,labels:segmented.labels,width:info.width}});
  }
  return result;
}

function resource(items,form,overrides={}) {
  let text=`[gd_resource type="SpriteFrames" load_steps=${1+items.reduce((n,i)=>n+1+i.frames.length,0)} format=3]\n\n`;
  const subs=[], clips=[];
  for(const item of items){
    text+=`[ext_resource type="Texture2D" path="res://${OUT}/atlas_${item.key}.png" id="${item.key}"]\n`;
    for(let i=0;i<item.frames.length;i++)subs.push(`[sub_resource type="AtlasTexture" id="${item.key}_${i}"]\natlas = ExtResource("${item.key}")\nregion = Rect2(${i%4*W},${Math.floor(i/4)*H},${W},${H})\nfilter_clip = true\n`);
    const directions=form==='transform'?DIRS:DIRS.filter(direction=>MASTER_FOR[direction]===item.key.split('_')[1]);
    for(const dir of directions){
      const definitions=form==='transform'?{transform:{frames:[0,1,2,3].map(i=>MASTERS.indexOf(MASTER_FOR[dir])*4+i),duration:0.9}}:CLIPS;
      for(const [name,clip] of Object.entries(definitions)){
        const frames=clipFrames(item.key,form==='transform'?name+'_'+MASTER_FOR[dir]:name,clip,item.frames.length,overrides);
        clips.push(`{ "frames": [${frames.map(i=>`{ "duration": 1.0, "texture": SubResource("${item.key}_${i}") }`).join(', ')}], "loop": ${!!clip.loop}, "name": &"${name}_${dir}", "speed": ${frames.length/clip.duration} }`);
      }
    }
  }
  return text+'\n'+subs.join('\n')+'\n[resource]\nanimations = [\n'+clips.join(',\n')+'\n]\n';
}
async function prepare(item,align) {
  if(!align||!Number.isFinite(align.scale)||!(align.scale>0)||!Array.isArray(align.roots)||align.roots.length!==item.cells.length||item.cells.length!==frameCount(item.key))throw Error(`${item.key}: explicit fixed scale and ${item.cells.length} roots required`);
  const frames=[], raws=[];
  for(const cell of item.cells){
    if(cell.count<400||cell.border>0)throw Error(`${item.key}/${cell.index}: empty or clipped source cell (${cell.border} border pixels); review windows`);
    const root=align.roots[cell.index];if(!Array.isArray(root)||root.length!==2||!root.every(Number.isFinite))throw Error('Invalid anchor');
    const [wx,wy,ww,wh]=cell.window; const [bx,by,ex,ey]=cell.bbox;
    // Crop alpha-zero margin only; retain ALL nonzero alpha, not only core pixels.
    const mask=item._segmentedPixels;
    const cellRaw=mask?maskedFramePixels(mask.data,mask.labels,mask.width,cell.window,cell.index)
      :await sharp(item.bytes).extract({left:wx,top:wy,width:ww,height:wh}).ensureAlpha().raw().toBuffer();
    const full=bounds(cellRaw,ww,wh,0).bbox;
    const l=wx+full[0],t=wy+full[1],sw=full[2]-full[0],sh=full[3]-full[1];
    // Crop the ownership-masked cell, never the original overlapping rectangle.
    // This preserves every assigned RGBA sample without borrowing a neighbor.
    const source=Buffer.alloc(sw*sh*4);
    for(let y=0;y<sh;y++)cellRaw.copy(source,y*sw*4,((full[1]+y)*ww+full[0])*4,((full[1]+y)*ww+full[0]+sw)*4);
    const rw=Math.round(sw*align.scale),rh=Math.round(sh*align.scale),left=Math.round(PIVOT[0]+(l-root[0])*align.scale),top=Math.round(PIVOT[1]+(t-root[1])*align.scale);
    if(rw<1||rh<1||left<0||top<0||left+rw>W||top+rh>H)throw Error(`${item.key}/${cell.index}: output clips at ${[left,top,rw,rh]}`);
    const scaled=await sharp(source,{raw:{width:sw,height:sh,channels:4}}).resize(rw,rh,{kernel:'lanczos3'}).raw().toBuffer();
    const raw=Buffer.alloc(W*H*4);for(let y=0;y<rh;y++)scaled.copy(raw,((top+y)*W+left)*4,y*rw*4,(y+1)*rw*4);
    const b=bounds(raw,W,H);if(b.border)throw Error(`${item.key}/${cell.index}: border pixels after packing`);
    raws.push(raw);frames.push({...cell,source_root:root,source_preserved_bbox:[l,t,l+sw,t+sh],source_pixels_sha256:hash(source),placement:[left,top,rw,rh],output_bbox:b.bbox,output_rgba_sha256:hash(raw)});
  }
  const height=H*Math.ceil(raws.length/COLS),atlasRaw=Buffer.alloc(W*COLS*height*4);
  raws.forEach((raw,i)=>{for(let y=0;y<H;y++)raw.copy(atlasRaw,((Math.floor(i/4)*H+y)*W*COLS+i%4*W)*4,y*W*4,(y+1)*W*4);});
  const atlas=await sharp(atlasRaw,{raw:{width:W*COLS,height,channels:4}}).png().toBuffer();
  for(let i=0;i<raws.length;i++){const r=await sharp(atlas).extract({left:i%4*W,top:Math.floor(i/4)*H,width:W,height:H}).raw().toBuffer();if(hash(r)!==hash(raws[i]))throw Error('RGBA packing mismatch');}
  return {...item,bytes:undefined,frames,raws,atlas,fixed_scale:align.scale,atlas_sha256:hash(atlas)};
}
async function previews(item,dir,overrides={}) {
  const review=abs('artifacts/paris_sprite_production');fs.mkdirSync(review,{recursive:true});
  await sharp(item.atlas).flatten({background:'#52606a'}).resize({width:1024}).jpeg({quality:88}).toFile(path.join(review,`review_${item.key}.jpg`));
  const defs=item.key==='transform_ALL'?Object.fromEntries(MASTERS.map((d,i)=>[`transform_${d}`,{frames:[0,1,2,3].map(f=>i*4+f),duration:.9}])):Object.fromEntries(Object.entries(CLIPS).map(([n,c])=>[n,c]));
  for(const [name,c] of Object.entries(defs)){if(name==='idle')continue;const pages=[];for(const idx of clipFrames(item.key,name,c,item.frames.length,overrides))pages.push(await sharp(item.raws[idx],{raw:{width:W,height:H,channels:4}}).flatten({background:'#52606a'}).raw().toBuffer());const delays=pages.map((_,i)=>(Math.round((i+1)*c.duration*100/pages.length)-Math.round(i*c.duration*100/pages.length))*10);await sharp(Buffer.concat(pages),{raw:{width:W,height:H*pages.length,channels:3,pageHeight:H}}).gif({delay:delays,loop:0}).toFile(path.join(review,`${item.key}_${name}.gif`));}
}
function portrait(form) {return `[gd_resource type="SpriteFrames" load_steps=3 format=3]\n\n[ext_resource type="Texture2D" path="res://${OUT}/atlas_${form}_E.png" id="1"]\n\n[sub_resource type="AtlasTexture" id="1"]\natlas = ExtResource("1")\nregion = Rect2(144,64,240,240)\nfilter_clip = true\n\n[resource]\nanimations = [{ "frames": [{ "duration": 1.0, "texture": SubResource("1") }], "loop": true, "name": &"idle_E", "speed": 1.0 }]\n`;}
async function main() {
  const argv=process.argv.slice(2), inspectOnly=argv.includes('--inspect'),partial=argv.includes('--allow-partial');
  const config=fs.existsSync(path.join(__dirname,'alignment.json'))?JSON.parse(fs.readFileSync(path.join(__dirname,'alignment.json'),'utf8').replace(/^\uFEFF/,'')):{};
  const keys=[...FORMS.flatMap(f=>MASTERS.map(d=>`${f}_${d}`)),'transform_ALL'].filter(k=>fs.existsSync(abs(`${SRC}/source_${k}.png`)));
  if(!keys.length||(!partial&&keys.length!==5))throw Error('Five native RGBA master sheets required. --allow-partial is production review only.');
  const items=[];for(const key of keys)items.push(await inspect(key,config[key]));
  if(inspectOnly){console.log(JSON.stringify(items.map(({bytes,...i})=>i),null,2));return;}
  const packed=[];for(const item of items)packed.push(await prepare(item,config[item.key]));
  const resources=[];for(const form of [...FORMS,'transform']){const selected=packed.filter(i=>i.key.startsWith(form+'_'));if(selected.length)resources.push([form,resource(selected,form,config.clip_overrides)]);}
  fs.mkdirSync(abs(OUT),{recursive:true});
  for(const item of packed){fs.writeFileSync(abs(`${OUT}/atlas_${item.key}.png`),item.atlas);await previews(item,null,config.clip_overrides);}
  for(const [form,text]of resources)fs.writeFileSync(abs(`${OUT}/frames_${form}.tres`),text);
  for(const form of FORMS)if(packed.some(i=>i.key===`${form}_E`))fs.writeFileSync(abs(`${OUT}/paris_${form==='spectral'?'':form+'_'}portrait.tres`),portrait(form));
  const manifest={schema:2,master_directions:MASTERS,runtime_directions:RUNTIME_DIRECTIONS,authored_drawings:packed.reduce((n,i)=>n+i.frames.length,0),animation_clip_count:resources.reduce((n,[,text])=>n+(text.match(/"name": &"/g)||[]).length,0),generator:'OpenAI built-in imagegen',complete:keys.length===5,canvas:[W,H],pivot:PIVOT,clips:CLIPS,clip_overrides:config.clip_overrides||{},policy:'Native RGBA artwork; explicit source windows or lossless core/BFS ownership segmentation and ground anchors; fixed per-sheet scale; two authored master angles E/N per form; S/W reuse E/N texture references and mirror only in the runtime; no offline mirroring, drawing, body warping or color-key removal; direct RGBA atlas copies verified after PNG encoding.',sheets:packed.map(({atlas,raws,...i})=>i)};
  fs.writeFileSync(abs(`${OUT}/manifest.json`),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({complete:manifest.complete,sheets:packed.length,verified_frames:packed.reduce((n,i)=>n+i.frames.length,0)}));
}
if(require.main===module)main().catch(e=>{console.error(e.stack);process.exitCode=1;});
module.exports={alphaStats,bounds,windows,validateWindows,clipFrames,inspect,prepare,resource,segmentSource,maskedFramePixels,CLIPS,MASTERS,MASTER_FOR,RUNTIME_DIRECTIONS,frameCount};
