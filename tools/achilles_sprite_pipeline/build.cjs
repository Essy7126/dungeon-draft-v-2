#!/usr/bin/env node
/** Deterministic mechanical packing only. Authored pixels come from ImageGen. */
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const ROOT = path.resolve(__dirname, '../..');
const SOURCE = 'art/source/characters/achilles/sprites_cour_des_sources_v1';
const OUTPUT = 'assets/characters/Achilles/sprites_cour_des_sources_v1';
const DIRECTIONS = ['N', 'E', 'S', 'W'];
const SIZE = 384, WIDTH = 512, ANCHOR = [256, 320], CORE_ALPHA = 32, EDGE_RADIUS = 2;
const MAPS = {
  idle: { indices: [0], speed: 1, loop: true },
  walk: { indices: [5,6,7,8,9,10,11,4], speed: 4 / 0.28, loop: true },
  attack: { indices: [0,12,13,14,14,15,0,0], speed: 12, loop: false, impact_frame: 3 },
};
const DIRECTION_MAPS={S:{attack:[0,0,13,14,14,15,0,0]},W:{walk:[8,9,10,11,4,5,6,7]}};
const animationIndices=(name,dir)=>DIRECTION_MAPS[dir]?.[name]||MAPS[name].indices;
const sha = b => crypto.createHash('sha256').update(b).digest('hex');
const round = v => Math.round(v * 10000) / 10000;
const median = values => { const v=values.slice().sort((a,b)=>a-b); return (v[Math.floor((v.length-1)/2)]+v[Math.floor(v.length/2)])/2; };

function extractComponents(data,w,h,expected=16) {
  const labels = new Int32Array(w*h), stack = new Int32Array(w*h), components=[];
  let id=0;
  for(let i=0;i<w*h;i++) {
    if(labels[i] || data[i*4+3]<=CORE_ALPHA) continue;
    id++; let n=0;
    stack[n++]=i; labels[i]=id;
    const c={id,count:0,bbox:[w,h,0,0],sx:0,sy:0,pixels:[]};
    while(n) {
      const p=stack[--n], x=p%w, y=Math.floor(p/w);
      c.count++;c.sx+=x;c.sy+=y;c.pixels.push(p);
      c.bbox[0]=Math.min(c.bbox[0],x);c.bbox[1]=Math.min(c.bbox[1],y);c.bbox[2]=Math.max(c.bbox[2],x+1);c.bbox[3]=Math.max(c.bbox[3],y+1);
      for(let dy=-1;dy<=1;dy++) for(let dx=-1;dx<=1;dx++) {
        const nx=x+dx,ny=y+dy,q=ny*w+nx;
        if(nx<0||ny<0||nx>=w||ny>=h||labels[q]||data[q*4+3]<=CORE_ALPHA) continue;
        labels[q]=id; stack[n++]=q;
      }
    }
    c.center=[c.sx/c.count,c.sy/c.count];components.push(c);
  }
  const large=components.filter(c=>c.count>=2000);
  if(large.length!==expected) throw Error(`Expected ${expected} complete sprites, found ${large.length}; inspect source, do not grid-crop it.`);
  const valid=new Set(large.map(c=>c.id));
  for(let p=0;p<labels.length;p++) if(!valid.has(labels[p])) labels[p]=0;
  // Preserve source alpha/RGB in the core and up to 2 pixels around it.
  // This removes only low-opacity alpha debris separated from the authored edge.
  const retained=labels.slice();
  for(const c of large) for(const p of c.pixels) {
    const x=p%w,y=Math.floor(p/w);
    for(let dy=-EDGE_RADIUS;dy<=EDGE_RADIUS;dy++) for(let dx=-EDGE_RADIUS;dx<=EDGE_RADIUS;dx++) {
      const nx=x+dx,ny=y+dy,q=ny*w+nx;
      if(nx<0||ny<0||nx>=w||ny>=h||!data[q*4+3]||retained[q])continue;
      retained[q]=c.id;
    }
  }
  return {components:large,labels:retained,discardedCoreComponents:components.filter(c=>c.count<2000).map(c=>({pixels:c.count,bbox:c.bbox}))};
}

async function buildDirection(dir, overrides) {
  const sourceRel=`${SOURCE}/source_${dir}.png`, sourcePath=path.join(ROOT,sourceRel);
  const original=fs.readFileSync(sourcePath), metadata=await sharp(original).metadata();
  if(!metadata.hasAlpha) throw Error(`${dir}: source lacks authentic alpha`);
  const {data,info}=await sharp(original).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const w=info.width,h=info.height,cw=w/4,ch=h/4;
  const {components,labels,discardedCoreComponents}=extractComponents(data,w,h);
  const ordered=new Array(16);
  for(const c of components) {
    const col=Math.min(3,Math.floor(c.center[0]/cw)),row=Math.min(3,Math.floor(c.center[1]/ch)),index=row*4+col;
    if(ordered[index])throw Error(`${dir}: ambiguous source cell ${index}`);
    c.col=col;c.row=row;c.index=index;ordered[index]=c;
  }
  if(ordered.some(c=>!c))throw Error(`${dir}: missing source cell`);
  let transparent=0,opaque=0,partial=0,removedPixels=0,removedAlphaSum=0,maxRemovedAlpha=0;
  for(let p=0;p<w*h;p++) {
    const a=data[p*4+3];if(!a)transparent++;else if(a===255)opaque++;else partial++;
    if(a&&!labels[p]){removedPixels++;removedAlphaSum+=a;maxRemovedAlpha=Math.max(maxRemovedAlpha,a);}
  }
  if(transparent/(w*h)<0.35)throw Error(`${dir}: suspiciously opaque background`);
  if(maxRemovedAlpha>CORE_ALPHA)throw Error(`${dir}: isolated opaque content found; needs source review`);
  const floors=[];
  for(let row=0;row<4;row++)floors[row]=Math.max(...ordered.slice(row*4,row*4+4).map(c=>c.bbox[3]-1));
  const idleRootXs=ordered.slice(0,4).map(c=>{
    const yMin=c.bbox[3]-(c.bbox[3]-c.bbox[1])*0.30;
    let min=w,max=0;
    for(const p of c.pixels){const y=Math.floor(p/w);if(y<yMin)continue;const x=p%w;min=Math.min(min,x);max=Math.max(max,x);}
    return (min+max)/2-c.col*cw;
  });
  const rootLocalX=overrides.root_local_x??median(idleRootXs);
  const idle0=ordered[0];
  // Warm red crest pixels are measured only, never keyed or recolored.
  const crestYs=idle0.pixels.filter(p=>Math.abs(p%w-rootLocalX)<cw*0.15&&data[p*4]>data[p*4+1]*1.4&&data[p*4]>data[p*4+2]*1.3&&data[p*4]>65&&Math.floor(p/w)<floors[0]-ch*0.6).map(p=>Math.floor(p/w));
  if(!crestYs.length&&!overrides.crest_top)throw Error(`${dir}: unable to find red crest for fixed scale`);
  const crestTop=overrides.crest_top??Math.min(...crestYs);
  const scale=overrides.scale??220/(floors[0]-crestTop);
  const baseContext={data,labels,w,h,cw,ch,floors,scale,rootLocalX,overrides};
  const attack=await require('./supplement.cjs')({fs,path,sharp,ROOT,SOURCE,dir,overrides:overrides.attack||{},extractComponents,sha,median,CORE_ALPHA});
  if(attack)ordered.splice(12,4,...attack.ordered);
  const frames=[],buffers=[];
  for(const c of ordered) {
    const context=attack&&c.index>=12?attack:baseContext;
    const {data,labels,w,h,cw,ch,floors,scale,rootLocalX}=context;
    const correction=context.overrides.frames?.[c.index]??{}, rootX=c.col*cw+rootLocalX+(correction.anchor_x??0),rootY=(c.index>=4&&c.index<12?floors[c.row]:c.bbox[3]-1)+(correction.anchor_y??0);
    let bx=w,by=h,ex=0,ey=0;
    for(let y=Math.max(0,c.bbox[1]-EDGE_RADIUS);y<Math.min(h,c.bbox[3]+EDGE_RADIUS);y++)for(let x=Math.max(0,c.bbox[0]-EDGE_RADIUS);x<Math.min(w,c.bbox[2]+EDGE_RADIUS);x++)if(labels[y*w+x]===c.id){bx=Math.min(bx,x);by=Math.min(by,y);ex=Math.max(ex,x+1);ey=Math.max(ey,y+1);}
    const sw=ex-bx,sh=ey-by,pixels=Buffer.alloc(sw*sh*4);
    for(let y=by;y<ey;y++)for(let x=bx;x<ex;x++)if(labels[y*w+x]===c.id)data.copy(pixels,((y-by)*sw+x-bx)*4,(y*w+x)*4,(y*w+x)*4+4);
    const rw=Math.max(1,Math.round(sw*scale)),rh=Math.max(1,Math.round(sh*scale));
    const left=Math.round(ANCHOR[0]+(bx-rootX)*scale),top=Math.round(ANCHOR[1]+(by-rootY)*scale);
    if(left<0||top<0||left+rw>WIDTH||top+rh>SIZE)throw Error(`${dir}/${c.index}: normalized sprite clips canvas ${[left,top,rw,rh]}; adjust shared scale or root`);
    const resized=await sharp(pixels,{raw:{width:sw,height:sh,channels:4}}).resize(rw,rh,{kernel:'lanczos3'}).png().toBuffer();
    const png=await sharp({create:{width:WIDTH,height:SIZE,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite([{input:resized,left,top}]).png().toBuffer();
    const raw=await sharp(png).raw().toBuffer();let outputPixels=0,borderPixels=0;let outputBBox=[WIDTH,SIZE,0,0];
    for(let y=0;y<SIZE;y++)for(let x=0;x<WIDTH;x++){const a=raw[(y*WIDTH+x)*4+3];if(a<=CORE_ALPHA)continue;outputPixels++;if(x===0||y===0||x===WIDTH-1||y===SIZE-1)borderPixels++;outputBBox[0]=Math.min(outputBBox[0],x);outputBBox[1]=Math.min(outputBBox[1],y);outputBBox[2]=Math.max(outputBBox[2],x+1);outputBBox[3]=Math.max(outputBBox[3],y+1);}
    if(outputPixels<5000||borderPixels)throw Error(`${dir}/${c.index}: empty or clipped output`);
    buffers.push(png);
    frames.push({index:c.index,source:c.source||sourceRel,source_cell:[c.col,c.row],source_core_bbox:c.bbox,source_preserved_bbox:[bx,by,ex,ey],source_root:[round(rootX),rootY],core_pixels:c.count,output_core_pixels:outputPixels,output_core_bbox:outputBBox,border_core_pixels:borderPixels,placement:[left,top,rw,rh],png_sha256:sha(png),crosses_nominal_cell:c.bbox[0]<c.col*cw||c.bbox[1]<c.row*ch||c.bbox[2]>(c.col+1)*cw||c.bbox[3]>(c.row+1)*ch});
  }
  const atlas=await sharp({create:{width:WIDTH*4,height:SIZE*4,channels:4,background:{r:0,g:0,b:0,alpha:0}}}).composite(buffers.map((input,i)=>({input,left:i%4*WIDTH,top:Math.floor(i/4)*SIZE}))).png().toBuffer();
  fs.writeFileSync(path.join(ROOT,OUTPUT,`atlas_${dir}.png`),atlas);
  // The preview is a mechanical contact sheet with a neutral background.
  await sharp(atlas).flatten({background:'#ddd6ba'}).resize(1024).jpeg({quality:90}).toFile(path.join(ROOT,OUTPUT,`preview_${dir}.jpg`));
  for(const [name,m]of Object.entries(MAPS)) {
    const indices=animationIndices(name,dir);const pages=[];for(const i of indices) pages.push(await sharp(buffers[i]).flatten({background:'#ddd6ba'}).raw().toBuffer());
    await sharp(Buffer.concat(pages),{raw:{width:WIDTH,height:SIZE*indices.length,channels:3,pageHeight:SIZE}}).gif({delay:indices.map(()=>Math.round(1000/m.speed)),loop:0}).toFile(path.join(ROOT,OUTPUT,`${name}_${dir}_preview.gif`));
  }
  return {direction:dir,supplemental_attack:attack?.manifest||null,source:sourceRel,source_sha256:sha(original),source_dimensions:[w,h],source_alpha:{zero:transparent,full:opaque,partial,transparent_fraction:round(transparent/(w*h))},segmentation:{threshold:CORE_ALPHA,edge_preservation_radius:EDGE_RADIUS,removed_pixels:removedPixels,removed_alpha_sum:removedAlphaSum,max_removed_alpha:maxRemovedAlpha,discarded_core_components:discardedCoreComponents},fixed_scale:round(scale),crest_top:crestTop,idle_ground_y:floors[0],shared_row_ground_y:floors,source_root_local_x:rootLocalX,idle_root_measurements:idleRootXs,atlas:`${OUTPUT}/atlas_${dir}.png`,atlas_sha256:sha(atlas),frames};
}

function spriteFrames(directions) {
  let s=`[gd_resource type="SpriteFrames" load_steps=${1+directions.length*17} format=3]\n\n`;
  directions.forEach(d=>s+=`[ext_resource type="Texture2D" path="res://${OUTPUT}/atlas_${d.direction}.png" id="${d.direction}"]\n`);
  s+='\n';
  for(const d of directions)for(let i=0;i<16;i++)s+=`[sub_resource type="AtlasTexture" id="Atlas_${d.direction}_${i}"]\natlas = ExtResource("${d.direction}")\nregion = Rect2(${i%4*WIDTH}, ${Math.floor(i/4)*SIZE}, ${WIDTH}, ${SIZE})\nfilter_clip = true\n\n`;
  const animations=[];
  for(const [name,m]of Object.entries(MAPS))for(const d of directions)animations.push(`{\n"frames": [${animationIndices(name,d.direction).map(i=>`{\n"duration": 1.0,\n"texture": SubResource("Atlas_${d.direction}_${i}")\n}`).join(', ')}],\n"loop": ${m.loop},\n"name": &"${name}_${d.direction}",\n"speed": ${Number.isInteger(m.speed) ? m.speed.toFixed(1) : m.speed}\n}`);
  return s+`[resource]\nanimations = [${animations.join(', ')}]\n`;
}

(async()=>{
  fs.mkdirSync(path.join(ROOT,SOURCE),{recursive:true});fs.mkdirSync(path.join(ROOT,OUTPUT),{recursive:true});
  const args=process.argv.slice(2);
  for(let i=0;i<args.length;i++)if(args[i]==='--source'||args[i]==='--attack-source'){
    const isAttack=args[i]==='--attack-source';
    const spec=args[++i],at=spec.indexOf('='),dir=spec.slice(0,at),source=spec.slice(at+1);
    if(!DIRECTIONS.includes(dir))throw Error(`Unknown direction ${dir}`);
    fs.copyFileSync(source,path.join(ROOT,SOURCE,`${isAttack?"attack":"source"}_${dir}.png`));
  }
  const configPath=path.join(__dirname,'alignment.json');
  const config=fs.existsSync(configPath)?JSON.parse(fs.readFileSync(configPath,'utf8')):{};
  const available=DIRECTIONS.filter(d=>fs.existsSync(path.join(ROOT,SOURCE,`source_${d}.png`)));
  if(available.length!==4&&!args.includes('--allow-partial'))throw Error('All N/E/S/W sources required; use --allow-partial only for development previews');
  const directions=[];
  for(const dir of available){const d=await buildDirection(dir,config[dir]||{});directions.push(d);console.log(`${dir}: 16 complete frames, scale ${d.fixed_scale}, source root ${d.source_root_local_x}, retained genuine alpha.`);}
  const manifest={schema_version:1,asset:'Achilles Cour des Sources sprite v1',generator:'OpenAI built-in ImageGen',complete:directions.length===4,canvas:[WIDTH,SIZE],foot_anchor:ANCHOR,body_target_height:220,directions:directions.map(d=>d.direction),animation_layout:MAPS,animation_overrides:DIRECTION_MAPS,walk_timing:{frames_per_cell:4,normal_cell_seconds:0.28,run_speed_multiplier:1.4,run_cell_seconds:0.2,contact_frame_indices:[3,7],note:"Cyclic source offsets put planted contact poses at each four-frame cell boundary; no texture or source pose changes."},source_grid:[4,4],segmentation_policy:'Eight-connected alpha >32 sprites; retain source RGB/alpha unchanged in each core and its two-pixel dilation. Discard only far alpha <=32 debris. Full-component extraction preserves spears crossing nominal grid boundaries. Walk shares ground per source row to preserve airborne poses. Idle and stationary attacks use the actual lowest foot contact per pose to prevent floating. Shared horizontal pivots and fixed source scales preserve authored body motion and knee bends.',sheets:directions};
  fs.writeFileSync(path.join(ROOT,OUTPUT,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  fs.writeFileSync(path.join(ROOT,OUTPUT,'achilles_sprite_frames.tres'),spriteFrames(directions));
  console.log(`Wrote ${directions.length*3} Godot animations; complete=${manifest.complete}`);
})().catch(error=>{console.error(error);process.exitCode=1;});
