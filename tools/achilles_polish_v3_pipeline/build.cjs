#!/usr/bin/env node
'use strict';
/** Mechanical source matting/packing. No pose synthesis, mirroring or body deformation. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const {matteBackground,connectedComponents}=require('./matting.cjs');
const ROOT=path.resolve(__dirname,'../..'),W=512,H=384,ANCHOR=[256,320],COLS=4;
const SOURCE='art/source/characters/achilles/sprites_polish_v3';
const OUTPUT='assets/characters/Achilles/sprites_polish_v3';
const REVIEW='artifacts/achilles_polish_v3_pipeline';
const LEGACY='assets/characters/Achilles/sprites_kit_v2/achilles_sprite_frames.tres';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const number=n=>Number.isInteger(n)?n.toFixed(1):String(n);
function splitAnimations(value){let depth=0,start=-1,quoted=false,escaped=false;const result=[];
 for(let i=0;i<value.length;i++){const c=value[i];if(quoted){if(escaped)escaped=false;else if(c==='\\')escaped=true;else if(c==='"')quoted=false;continue;}
 if(c==='"'){quoted=true;continue;}if(c==='{'){if(depth++===0)start=i;}else if(c==='}'&&--depth===0)result.push(value.slice(start,i+1));}
 if(depth||quoted)throw Error('Unbalanced SpriteFrames');return result;}
function loadLegacy(){const bytes=fs.readFileSync(path.join(ROOT,LEGACY)),text=bytes.toString('utf8'),at=text.indexOf('[resource]'),start=text.indexOf('animations = [',at);
 const header=text.slice(0,at).replace(/^\[gd_resource[^\n]*\]\s*/,''),blocks=splitAnimations(text.slice(start+'animations = ['.length,text.lastIndexOf(']'))),map=new Map();
 for(const block of blocks){const name=block.match(/"name"\s*:\s*&"([^"]+)"/)?.[1];if(!name||map.has(name))throw Error('Duplicate legacy animation');map.set(name,block);}
 if(map.size!==40)throw Error('Expected full forty-clip v2 source');return{header,map,sha256:sha(bytes),resourceCount:(header.match(/\[(?:ext_resource|sub_resource)\b/g)||[]).length};}
function distanceBox(p,b){const dx=Math.max(b[0]-p[0],0,p[0]-b[2]),dy=Math.max(b[1]-p[1],0,p[1]-b[3]);return dx*dx+dy*dy;}
async function loadSource(config){
 const filename=path.join(ROOT,SOURCE,config.source),original=fs.readFileSync(filename),decoded=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const {width,height}=decoded.info,matte=matteBackground(decoded.data,width,height,config.key??{mode:'native'});
 let cc=connectedComponents(matte.data,width,height),big=cc.components.filter(c=>c.count>=2000),dust=[];
 // Only disconnected neutral remnants from a painted background qualify.
 if((config.key?.mode??'native')!=='native'){
  const mainIds=new Set(big.map(c=>c.id)),near=new Uint8Array(width*height);
  for(let p=0;p<near.length;p++)if(mainIds.has(cc.labels[p])){const x=p%width,y=Math.floor(p/width);for(let dy=-2;dy<=2;dy++)for(let dx=-2;dx<=2;dx++){const xx=x+dx,yy=y+dy;if(xx>=0&&yy>=0&&xx<width&&yy<height)near[yy*width+xx]=1;}}
  for(const c of cc.components){if(c.count>16)continue;let neutral=true,close=false;
   for(let y=c.bbox[1];y<c.bbox[3];y++)for(let x=c.bbox[0];x<c.bbox[2];x++){const p=y*width+x;if(cc.labels[p]!==c.id)continue;
    const rgb=[decoded.data[p*4],decoded.data[p*4+1],decoded.data[p*4+2]];if(Math.min(...rgb)<70||Math.max(...rgb)-Math.min(...rgb)>35)neutral=false;if(near[p])close=true;}
   if(neutral&&!close){dust.push({pixels:c.count,bbox:c.bbox});for(let y=c.bbox[1];y<c.bbox[3];y++)for(let x=c.bbox[0];x<c.bbox[2];x++){const p=y*width+x;if(cc.labels[p]===c.id)matte.data[p*4+3]=0;}}
  }
  if(dust.length){cc=connectedComponents(matte.data,width,height);big=cc.components.filter(c=>c.count>=2000);}
 }
 const byIndex=new Map();for(const c of big){const col=Math.min(config.columns-1,Math.floor(c.center[0]/(width/config.columns))),row=Math.min(config.rows-1,Math.floor(c.center[1]/(height/config.rows))),i=row*config.columns+col;
  if(byIndex.has(i))throw Error('Two major silhouettes occupy source cell '+i+' in '+config.source);byIndex.set(i,c);}
 const owners=new Int16Array(width*height);owners.fill(-1);const assignments=new Map();for(const [i,c]of byIndex)assignments.set(c.id,i);
 for(const c of cc.components){if(assignments.has(c.id))continue;let nearest=null,score=Infinity;for(const [i,body]of byIndex){const d=distanceBox(c.center,body.bbox);if(d<score){score=d;nearest=i;}}if(nearest!==null)assignments.set(c.id,nearest);}
 for(let p=0;p<owners.length;p++)if(matte.data[p*4+3])owners[p]=assignments.get(cc.labels[p])??-1;
 for(let p=0;p<owners.length;p++)if(matte.data[p*4+3]){for(let channel=0;channel<4;channel++)if(matte.data[p*4+channel]!==decoded.data[p*4+channel]&&(channel===3||!matte.edgeCorrections[p]))throw Error('Retained body pixel changed outside authorized edge RGB recovery');}
 return{filename,original,width,height,data:matte.data,owners,byIndex,report:{...matte.report,neutral_dust:dust,source_sha256:sha(original),dimensions:[width,height]}};
}
function crestMeasurement(source,c){const width=c.bbox[2]-c.bbox[0],height=Math.ceil((c.bbox[3]-c.bbox[1])*0.4),mask=Buffer.alloc(width*height*4);for(let yy=0;yy<height;yy++)for(let xx=0;xx<width;xx++){const p=(c.bbox[1]+yy)*source.width+c.bbox[0]+xx,r=source.data[p*4],g=source.data[p*4+1],b=source.data[p*4+2];if(source.data[p*4+3]&&r>80&&r>g*1.45&&r>b*1.4)mask[(yy*width+xx)*4+3]=255;}const cc=connectedComponents(mask,width,height).components.sort((a,b)=>b.count-a.count);return cc.length?c.bbox[1]+cc[0].bbox[1]:null;}
async function inspect(config){for(const [key,cfg]of Object.entries(config.sheets)){const source=await loadSource(cfg),selected=cfg.indices??Array.from({length:8},(_,i)=>i);const measured=[];
 for(const index of selected){const c=source.byIndex.get(index);if(!c)throw Error('Missing source '+key+'/'+index);measured.push({source_index:index,bbox:c.bbox,center:c.center.map(Math.round),crest_top:crestMeasurement(source,c),ground_y:c.bbox[3]});}
 fs.mkdirSync(path.join(ROOT,REVIEW),{recursive:true});await sharp(source.data,{raw:{width:source.width,height:source.height,channels:4}}).png().toFile(path.join(ROOT,REVIEW,'matte_'+key+'.png'));console.log(JSON.stringify({key,source:cfg.source,measurements:measured}));}}
async function prepareSheet(key,cfg){
 if(!/^(walk|bow|bow_piercing|bow_death|volley)_[NESW]$/.test(key))throw Error('Unsupported action/direction '+key);
 const source=await loadSource(cfg),indices=cfg.indices??Array.from({length:8},(_,i)=>i),mapping=cfg.mapping??Array.from({length:indices.length},(_,i)=>i);
 if(!Number.isFinite(cfg.scale)||cfg.scale<=0||!Array.isArray(cfg.roots)||cfg.roots.length!==indices.length)throw Error('Explicit fixed scale and source roots required: '+key);
 const buffers=[],frames=[];
 for(let index=0;index<indices.length;index++){
  const srcIndex=indices[index],body=source.byIndex.get(srcIndex);if(!body)throw Error('Missing source pose '+key+'/'+srcIndex);
  let bx=source.width,by=source.height,ex=0,ey=0,kept=0;
  for(let p=0;p<source.owners.length;p++)if(source.owners[p]===srcIndex&&source.data[p*4+3]){const x=p%source.width,y=Math.floor(p/source.width);bx=Math.min(bx,x);by=Math.min(by,y);ex=Math.max(ex,x+1);ey=Math.max(ey,y+1);kept++;}
  const width=ex-bx,height=ey-by,pixels=Buffer.alloc(width*height*4);
  for(let y=by;y<ey;y++)for(let x=bx;x<ex;x++){const p=y*source.width+x;if(source.owners[p]===srcIndex)source.data.copy(pixels,((y-by)*width+x-bx)*4,p*4,p*4+4);}
  const root=cfg.roots[index];if(root.length!==2||root.some(v=>!Number.isFinite(v)))throw Error('Bad anchor');
  const rw=Math.max(1,Math.round(width*cfg.scale)),rh=Math.max(1,Math.round(height*cfg.scale)),left=Math.round(ANCHOR[0]+(bx-root[0])*cfg.scale),top=Math.round(ANCHOR[1]+(by-root[1])*cfg.scale);
  if(left<1||top<1||left+rw>=W||top+rh>=H)throw Error('Canvas clips source '+key+'/'+srcIndex+' '+[left,top,rw,rh]);
  const resized=await sharp(pixels,{raw:{width,height,channels:4}}).resize(rw,rh,{kernel:'lanczos3'}).png().toBuffer();
  const normalized=Buffer.alloc(W*H*4),scaledRaw=await sharp(resized).raw().toBuffer();for(let row=0;row<rh;row++)scaledRaw.copy(normalized,((top+row)*W+left)*4,row*rw*4,(row+1)*rw*4);const png=await sharp(normalized,{raw:{width:W,height:H,channels:4}}).png().toBuffer();
  buffers.push(png);frames.push({index,source_index:srcIndex,source_bbox:[bx,by,ex,ey],source_root:root,kept_source_pixels:kept,crest_top:crestMeasurement(source,body),scale:cfg.scale,placement:[left,top,rw,rh],sha256:sha(png),rgba_sha256:sha(normalized)});
 }
 if(mapping.length!==8||mapping.some(i=>!Number.isInteger(i)||i<0||i>=buffers.length))throw Error('Eight valid playback poses required '+key);
 const atlasWidth=W*COLS,atlasHeight=H*Math.ceil(buffers.length/COLS),atlasRaw=Buffer.alloc(atlasWidth*atlasHeight*4);for(let i=0;i<buffers.length;i++){const raw=await sharp(buffers[i]).raw().toBuffer();if(sha(raw)!==frames[i].rgba_sha256)throw Error('Normalized frame roundtrip mismatch');for(let row=0;row<H;row++)raw.copy(atlasRaw,((Math.floor(i/COLS)*H+row)*atlasWidth+i%COLS*W)*4,row*W*4,(row+1)*W*4);}const atlas=await sharp(atlasRaw,{raw:{width:atlasWidth,height:atlasHeight,channels:4}}).png().toBuffer();
 return{key,cfg,frames,buffers,atlas,mapping,source_report:source.report,atlas_sha256:sha(atlas)};
}
function compileFrames(sheets,legacy,overrides={}){
 const available=new Map(sheets.map(s=>[s.key,s])),blocks=new Map(legacy.map),newHeaders=[],subs=[];let added=0;
 for(const item of sheets){newHeaders.push('[ext_resource type="Texture2D" path="res://'+OUTPUT+'/atlas_'+item.key+'.png" id="Polish_'+item.key+'"]');
  item.frames.forEach((f,i)=>subs.push('[sub_resource type="AtlasTexture" id="Polish_'+item.key+'_'+i+'"]\natlas = ExtResource("Polish_'+item.key+'")\nregion = Rect2('+[i%COLS*W,Math.floor(i/COLS)*H,W,H].join(', ')+')\nfilter_clip = true\n'));
  added+=item.frames.length+1;
  const weights=item.cfg.weights??item.mapping.map(()=>1);if(weights.length!==8||weights.some(v=>!Number.isFinite(v)||v<=0))throw Error('Invalid weights '+item.key);
  const refs=item.mapping.map(i=>'Polish_'+item.key+'_'+i);
  for(const [frame,def]of Object.entries(overrides[item.key]??{})){const i=Number(frame),target=available.get(def.sheet);if(!Number.isInteger(i)||i<0||i>=refs.length||!target||!Number.isInteger(def.index)||def.index<0||def.index>=target.frames.length)throw Error('Invalid clip override '+item.key+'/'+frame);refs[i]='Polish_'+def.sheet+'_'+def.index;}
  const fps=item.cfg.speed??(weights.reduce((a,b)=>a+b,0)/(item.cfg.duration_seconds??0.74));
  blocks.set(item.key,'{\n"frames": ['+refs.map((id,i)=>'{\n"duration": '+number(weights[i])+',\n"texture": SubResource("'+id+'")\n}').join(', ')+'],\n"loop": '+item.key.startsWith('walk_')+',\n"name": &"'+item.key+'",\n"speed": '+number(fps)+'\n}');
 }
 for(const [name,block]of legacy.map)if(!available.has(name)&&blocks.get(name)!==block)throw Error('Unchanged legacy clip altered '+name);
 const split=legacy.header.indexOf('[sub_resource'),header=legacy.header.slice(0,split)+newHeaders.join('\n')+'\n\n'+legacy.header.slice(split)+subs.join('\n');
 return{text:'[gd_resource type="SpriteFrames" load_steps='+(1+legacy.resourceCount+added)+' format=3]\n\n'+header+'\n[resource]\nanimations = ['+[...blocks.values()].join(', ')+']\n',count:blocks.size,preserved:[...legacy.map.keys()].filter(k=>!available.has(k))};
}
async function preview(item,allSheets,overrides){
 const dir=path.join(ROOT,REVIEW);fs.mkdirSync(dir,{recursive:true});
 for(const [name,bg]of [['light','#ded8c3'],['dark','#34454b']]){
  let svg='<svg xmlns="http://www.w3.org/2000/svg" width="'+(W*4)+'" height="'+(H*Math.ceil(item.frames.length/4))+'">';
  for(let i=0;i<item.frames.length;i++){const x=i%4*W,y=Math.floor(i/4)*H;svg+='<text x="'+(x+12)+'" y="'+(y+28)+'" fill="#999999" font-family="sans-serif" font-size="22">'+item.key+' src '+item.frames[i].source_index+'</text><path d="M'+(x+248)+','+(y+320)+'h16 M'+(x+256)+','+(y+313)+'v14" stroke="#ee56c6" stroke-width="2"/>';}
  svg+='</svg>';const marked=await sharp(item.atlas).composite([{input:Buffer.from(svg)}]).flatten({background:bg}).png().toBuffer();await sharp(marked).resize(1024).jpeg({quality:90}).toFile(path.join(dir,'review_'+item.key+'_'+name+'.jpg'));
 }
 const pages=[];for(let frame=0;frame<item.mapping.length;frame++){const def=overrides[item.key]?.[frame],source=def?allSheets.find(s=>s.key===def.sheet):item,index=def?def.index:item.mapping[frame];if(!source?.buffers[index])throw Error('Preview override missing');pages.push(await sharp(source.buffers[index]).flatten({background:'#ded8c3'}).raw().toBuffer());}
 const weights=item.cfg.weights??item.mapping.map(()=>1),total=weights.reduce((a,b)=>a+b,0),duration=item.key.startsWith('walk_')?0.56:(item.cfg.duration_seconds??0.74);
 const release=item.cfg.release_seconds??duration*.5,marker=item.cfg.release_frame??4,before=weights.slice(0,marker).reduce((a,b)=>a+b,0),after=total-before;let cumulative=0,lastCentis=0;const delays=weights.map((v,i)=>{cumulative+=item.key.startsWith('walk_')?duration*v/total:(i<marker?release*v/before:(duration-release)*v/after);const end=Math.round(cumulative*100),ms=(end-lastCentis)*10;lastCentis=end;return Math.max(10,ms);});
 await sharp(Buffer.concat(pages),{raw:{width:W,height:H*pages.length,channels:3,pageHeight:H}}).gif({delay:delays,loop:0}).toFile(path.join(dir,item.key+'_preview.gif'));
}
async function build(config){
 const sheets=[];for(const [key,cfg]of Object.entries(config.sheets))sheets.push(await prepareSheet(key,cfg));
 const legacy=loadLegacy(),compiled=compileFrames(sheets,legacy,config.clip_overrides??{});
 const out=path.join(ROOT,OUTPUT);fs.mkdirSync(out,{recursive:true});
 for(const item of sheets){fs.writeFileSync(path.join(out,'atlas_'+item.key+'.png'),item.atlas);await preview(item,sheets,config.clip_overrides??{});}
 fs.writeFileSync(path.join(out,'achilles_sprite_frames.tres'),compiled.text);
 const expected=['walk','bow','bow_piercing','bow_death','volley'].flatMap(s=>['N','E','S','W'].map(d=>s+'_'+d));
 const manifest={schema_version:3,asset:'Achilles classic sprite polish v3',complete:expected.every(k=>sheets.some(s=>s.key===k)),
  canvas:[W,H],foot_anchor:ANCHOR,source_generator:'OpenAI ImageGen',background_removal_authorized_by_user:true,
  source_pixel_policy:'Source originals retained. Matting removes keyed background and declared neutral dust. Optional magenta-edge RGB recovery is reported per source and preserves alpha; all other retained RGBA is byte-identical before one fixed uniform scale per action/direction.',
  legacy:{path:LEGACY,sha256:legacy.sha256,preserved_clips:compiled.preserved},clip_count:compiled.count,
  missing_clips:expected.filter(k=>!sheets.some(s=>s.key===k)),clip_overrides:config.clip_overrides??{},
  sheets:sheets.map(s=>({key:s.key,source:SOURCE+'/'+s.cfg.source,selected_source_indices:s.cfg.indices,alignment_note:s.cfg.alignment_note??'',mapping_note:s.cfg.mapping_note??'',duration_seconds:s.cfg.duration_seconds??0.56,release_seconds:s.cfg.release_seconds??null,release_frame:s.cfg.release_frame??null,release_grip_atlas:s.cfg.release_grip_atlas??null,cast_origin_local:s.cfg.cast_origin_local??null,source_report:s.source_report,atlas:OUTPUT+'/atlas_'+s.key+'.png',atlas_sha256:s.atlas_sha256,mapping:s.mapping,weights:s.cfg.weights??s.mapping.map(()=>1),frames:s.frames}))};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({complete:manifest.complete,sheets:sheets.length,clips:compiled.count,missing:manifest.missing_clips}));
 return manifest;
}
if(require.main===module){const cfg=JSON.parse(fs.readFileSync(path.join(__dirname,'alignment.json'),'utf8'));(process.argv.includes('--inspect')?inspect(cfg):build(cfg)).catch(e=>{console.error(e.stack);process.exitCode=1;});}
module.exports={splitAnimations,loadLegacy,loadSource,prepareSheet,compileFrames,build};
