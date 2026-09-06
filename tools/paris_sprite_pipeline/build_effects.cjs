#!/usr/bin/env node
'use strict';

// Reuse the mage's audited RGBA measurements and byte-copy extraction. Paris
// never invokes its boundary cleaning: every source pixel remains assigned.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { analyze, extractRaw, outputLocation } = require('../philosopher_sprite_pipeline/build_effects.cjs');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const ROOT = path.resolve(__dirname, '../..');
const SOURCE = 'art/source/vfx/paris/sprites_v1/source_effects.png';
const OUTPUT = 'assets/vfx/paris/sprites_v1';
const ANIMATIONS = ['arrow','frost','fire','vortex','impact','whip','hellfire','transform'];
const DURATIONS = {arrow:0.20,frost:0.20,fire:0.20,vortex:0.30,impact:0.30,whip:0.34,hellfire:0.40,transform:0.90};
const ICON_ANIMATIONS = {spectral_arrow:'arrow',ice_arrow:'frost',fire_arrow:'fire',vortex_arrow:'vortex',
  vortex_step:'vortex',infernal_whip:'whip',infernal_sweep:'hellfire',infernal_pull:'whip',transformation:'transform'};
const SIZE=256, COLUMNS=4, ROWS=8, MARGIN=12, INNER=SIZE-MARGIN*2;
const sha = buffer => crypto.createHash('sha256').update(buffer).digest('hex');

function options(argv) {
  const result={source:SOURCE,output:OUTPUT,inspect:false,help:false};
  for(let index=0;index<argv.length;index++) {
    const key=argv[index];
    if(key==='--inspect') result.inspect=true;
    else if(key==='--help'||key==='-h') result.help=true;
    else if(['--source','--output','--layout'].includes(key)) {
      const value=argv[++index];
      if(!value||value.startsWith('--')) throw Error(key+' requires a path.');
      result[key.slice(2)]=value;
    } else throw Error('Unknown option: '+key);
  }
  return result;
}

function validateLayout(layout, metadata, sourceHash) {
  if(!layout||typeof layout!=='object'||Array.isArray(layout)) throw Error('A reviewed source layout is required.');
  if(layout.source_sha256!==sourceHash) throw Error('Layout belongs to another source SHA-256; remeasure the windows.');
  if(!Array.isArray(layout.source_size)||layout.source_size.length!==2||layout.source_size[0]!==metadata.width||layout.source_size[1]!==metadata.height)
    throw Error('Layout dimensions do not match the source.');
  if(!Array.isArray(layout.frames)||layout.frames.length!==32) throw Error('Exactly 32 reviewed source windows are required.');
  const coverage=new Uint8Array(metadata.width*metadata.height);
  return layout.frames.map((frame,index)=>{
    const label=ANIMATIONS[Math.floor(index/4)]+'['+index%4+']';
    if(frame.animation!==ANIMATIONS[Math.floor(index/4)]||frame.frame!==index%4) throw Error('Unexpected animation order at '+label);
    const box=frame.window, anchor=frame.anchor;
    if(!Array.isArray(box)||box.length!==4||!box.every(Number.isInteger)||box[0]<0||box[1]<0||box[2]<=0||box[3]<=0||
      box[0]+box[2]>metadata.width||box[1]+box[3]>metadata.height) throw Error('Invalid integer source window: '+label);
    if(!Array.isArray(anchor)||anchor.length!==2||!anchor.every(Number.isInteger)||anchor[0]<box[0]||anchor[0]>=box[0]+box[2]||
      anchor[1]<box[1]||anchor[1]>=box[1]+box[3]) throw Error('Invalid explicit anchor: '+label);
    if(!Number.isInteger(frame.reviewed_boundary_alpha_max)||frame.reviewed_boundary_alpha_max<0||frame.reviewed_boundary_alpha_max>40)
      throw Error('A measured boundary ceiling between 0 and 40 is required: '+label);
    for(let y=box[1];y<box[1]+box[3];y++)for(let x=box[0];x<box[0]+box[2];x++) {
      if(coverage[y*metadata.width+x]++) throw Error('Source windows overlap: '+label);
    }
    if(index===31&&!coverage.every(value=>value===1)) throw Error('Source windows leave unassigned pixels.');
    return {animation:frame.animation,frame:frame.frame,
      crop:{left:box[0],top:box[1],width:box[2],height:box[3]},
      anchor:[anchor[0]-box[0],anchor[1]-box[1]],global_anchor:anchor.slice(),
      reviewed_boundary_alpha_max:frame.reviewed_boundary_alpha_max};
  });
}

function boundaryAlpha(raw,width,height) {
  let maximum_alpha=0,nonzero_pixels=0,alpha_sum=0;
  for(let y=0;y<height;y++)for(let x=0;x<width;x++) {
    if(x&&y&&x!==width-1&&y!==height-1) continue;
    const alpha=raw[(y*width+x)*4+3];
    maximum_alpha=Math.max(maximum_alpha,alpha);alpha_sum+=alpha;if(alpha)nonzero_pixels++;
  }
  return {maximum_alpha,nonzero_pixels,alpha_sum,pixels_removed:0};
}

function packRaw(frames) {
  if(!Array.isArray(frames)||frames.length!==32||frames.some(frame=>!Buffer.isBuffer(frame)||frame.length!==SIZE*SIZE*4))
    throw Error('Atlas requires exactly 32 RGBA frames of 256 × 256.');
  const width=SIZE*COLUMNS, atlas=Buffer.alloc(width*SIZE*ROWS*4);
  frames.forEach((raw,index)=>{
    const left=index%4*SIZE,top=Math.floor(index/4)*SIZE;
    for(let y=0;y<SIZE;y++)raw.copy(atlas,((top+y)*width+left)*4,y*SIZE*4,(y+1)*SIZE*4);
  });
  return atlas;
}

function resourceText(atlasPath) {
  const blocks=['[gd_resource type="SpriteFrames" load_steps=34 format=3]',
    `[ext_resource type="Texture2D" path="${atlasPath}" id="1_atlas"]`];
  ANIMATIONS.forEach((name,row)=>{
    for(let col=0;col<4;col++)blocks.push(`[sub_resource type="AtlasTexture" id="Frame_${name}_${col}"]\natlas = ExtResource("1_atlas")\nregion = Rect2(${col*SIZE}, ${row*SIZE}, 256, 256)`);
  });
  const animations=ANIMATIONS.map(name=>'{\n"frames": ['+Array.from({length:4},(_,index)=>
    `{\n"duration": 1.0,\n"texture": SubResource("Frame_${name}_${index}")\n}`).join(', ')+
    `],\n"loop": false,\n"name": &"${name}",\n"speed": ${(4/DURATIONS[name]).toFixed(6)}\n}`);
  blocks.push('[resource]\nanimations = ['+animations.join(', ')+']');
  return blocks.join('\n\n')+'\n';
}

function iconResources(atlasPath) {
  return Object.fromEntries(Object.entries(ICON_ANIMATIONS).map(([id,animation])=>[id,
    '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'+
    `[ext_resource type="Texture2D" path="${atlasPath}" id="1_atlas"]\n\n`+
    `[resource]\natlas = ExtResource("1_atlas")\nregion = Rect2(512, ${ANIMATIONS.indexOf(animation)*SIZE}, 256, 256)\n`]));
}

async function prepare(sourcePath,layout) {
  const bytes=fs.readFileSync(sourcePath), metadata=await sharp(bytes).metadata();
  if(metadata.format!=='png'||!metadata.hasAlpha||metadata.channels!==4||metadata.depth!=='uchar')
    throw Error('Source must be native 8-bit RGBA PNG. Alpha is never synthesized.');
  if(metadata.orientation&&metadata.orientation!==1) throw Error('Rotated source metadata is unsupported.');
  const {data,info}=await sharp(bytes).raw().toBuffer({resolveWithObject:true});
  const sourceAlpha=analyze(data,info.width,info.height);
  if(sourceAlpha.transparent_pixels<info.width*info.height*.2) throw Error('Source lacks native transparency; opaque/baked backgrounds are rejected.');
  const declared=validateLayout(layout,metadata,sha(bytes)), frames=[];
  for(const frame of declared) {
    const raw=extractRaw(data,info.width,frame.crop), alpha=analyze(raw,frame.crop.width,frame.crop.height);
    const border=boundaryAlpha(raw,frame.crop.width,frame.crop.height);
    if(!alpha.alpha_bounds.all||!alpha.alpha_bounds.core) throw Error(frame.animation+'['+frame.frame+']: empty or invisible frame.');
    if(border.maximum_alpha>frame.reviewed_boundary_alpha_max) throw Error(frame.animation+'['+frame.frame+']: boundary crosses unreviewed alpha '+border.maximum_alpha+'.');
    frames.push({animation:frame.animation,frame:frame.frame,source_crop:frame.crop,
      source_anchor:frame.anchor,source_anchor_global:frame.global_anchor,source_alpha:alpha,
      source_rgba_sha256:sha(raw),source_boundary: border,raw});
  }
  if(frames.reduce((sum,frame)=>sum+frame.source_alpha.alpha_sum,0)!==sourceAlpha.alpha_sum)
    throw Error('Source alpha coverage is incomplete.');
  const rows=[],packed=[];
  for(let row=0;row<ROWS;row++) {
    const entries=frames.slice(row*4,row*4+4);
    let radius=0;
    for(const frame of entries) {
      const box=frame.source_alpha.alpha_bounds.all,[x,y]=frame.source_anchor;
      radius=Math.max(radius,x-box[0],y-box[1],box[2]-x,box[3]-y);
    }
    radius=Math.ceil(radius+2);
    const side=radius*2,scale=INNER/side;
    rows.push({animation:ANIMATIONS[row],common_radius:radius,common_scale:scale,
      output_anchor:[128,128],source_anchors:entries.map(frame=>frame.source_anchor_global),
      per_frame_recentering:false,per_frame_rescaling:false});
    for(const frame of entries) {
      const crop={left:frame.source_anchor[0]-radius,top:frame.source_anchor[1]-radius,width:side,height:side};
      const cropped=extractRaw(frame.raw,frame.source_crop.width,crop);
      const croppedAlpha=analyze(cropped,side,side);
      if(croppedAlpha.alpha_sum!==frame.source_alpha.alpha_sum) throw Error('Common row crop discarded source alpha.');
      const resized=side===INNER?cropped:await sharp(cropped,{raw:{width:side,height:side,channels:4}})
        .resize(INNER,INNER,{kernel:'lanczos3'}).raw().toBuffer();
      const raw=Buffer.alloc(SIZE*SIZE*4);
      for(let y=0;y<INNER;y++)resized.copy(raw,((y+MARGIN)*SIZE+MARGIN)*4,y*INNER*4,(y+1)*INNER*4);
      const alpha=analyze(raw,SIZE,SIZE);
      if(!alpha.alpha_bounds.all||Math.min(...alpha.margins.all)<MARGIN) throw Error('Packed effect alpha is missing or clipped.');
      frame.common_anchor_crop=crop;frame.cropped_alpha_sum=croppedAlpha.alpha_sum;
      frame.packed_alpha=alpha;frame.packed_rgba_sha256=sha(raw);delete frame.raw;packed.push(raw);
    }
  }
  const rawAtlas=packRaw(packed), atlas=await sharp(rawAtlas,{raw:{width:1024,height:2048,channels:4}}).png().toBuffer();
  const decoded=await sharp(atlas).raw().toBuffer();
  for(let index=0;index<32;index++) {
    const raw=extractRaw(decoded,1024,{left:index%4*SIZE,top:Math.floor(index/4)*SIZE,width:SIZE,height:SIZE});
    if(!raw.equals(packed[index])) throw Error('PNG atlas round-trip changed frame '+index+'.');
  }
  return {atlas,manifest:{schema_version:1,complete:true,
    source:{path:path.relative(ROOT,sourcePath).split(path.sep).join('/'),sha256:sha(bytes),size:[info.width,info.height],channels:4,
      has_alpha:true,alpha_sum:sourceAlpha.alpha_sum,transparent_pixels:sourceAlpha.transparent_pixels},
    atlas:{size:[1024,2048],frame_size:[256,256],sha256:sha(atlas)},
    animation_order:ANIMATIONS,frames_per_animation:4,authored_duration_seconds:DURATIONS,
    runtime_duration_overrides:{vortex_teleport:0.48,hellfire_arrow_impact:0.30},
    icon_frames:Object.fromEntries(Object.entries(ICON_ANIMATIONS).map(([id,animation])=>[id,{animation,frame:2,region:[512,ANIMATIONS.indexOf(animation)*256,256,256]}])),
    explicit_source_layout:layout,rows,frames,
    processing:{method:'Reviewed SHA-bound rectangles, byte-copy RGBA extraction, one common anchored square and scale per animation, Lanczos3 resampling, transparent padding and byte-copy atlas.',
      all_source_pixels_assigned_exactly_once:true,all_nonzero_source_alpha_preserved_before_resampling:true,
      color_keying:false,segmentation:false,pixel_redraw:false,boundary_cleaning:false,alpha_pixels_removed:0,
      source_boundary_alpha_is_measured_only:true,frame_border_margin_pixels:MARGIN,
      orientation:'Arrows authored pointing right, whip authored left to right; pipeline applies no rotation or mirror.',
      resampling_interpolates_rgba:true},sharp_version:sharp.versions.sharp}};
}

async function build(settings={}) {
  const source=path.resolve(ROOT,settings.source||SOURCE), output=outputLocation(settings.output||OUTPUT);
  const layoutPath=settings.layout?path.resolve(ROOT,settings.layout):path.join(__dirname,'effects_source_layout.json');
  const bytes=fs.readFileSync(layoutPath), layout=JSON.parse(bytes.toString('utf8').replace(/^\uFEFF/,''));
  const result=await prepare(source,layout);
  result.manifest.source_layout_file={path:path.relative(ROOT,layoutPath).split(path.sep).join('/'),sha256:sha(bytes)};
  result.manifest.atlas.path=output.relative+'/effects.png';
  if(!settings.inspect) {
    fs.mkdirSync(output.absolute,{recursive:true});
    fs.writeFileSync(path.join(output.absolute,'effects.png'),result.atlas);
    fs.writeFileSync(path.join(output.absolute,'effects.tres'),resourceText('res://'+output.relative+'/effects.png'));
    fs.mkdirSync(path.join(output.absolute,'icons'),{recursive:true});
    for(const[name,resource]of Object.entries(iconResources('res://'+output.relative+'/effects.png')))
      fs.writeFileSync(path.join(output.absolute,'icons',name+'.tres'),resource);
    fs.writeFileSync(path.join(output.absolute,'manifest.json'),JSON.stringify(result.manifest,null,2)+'\n');
    for(const[name,background]of [['light','#deddd6'],['gray','#5a616a'],['dark','#192127']])
      await sharp(result.atlas).flatten({background}).jpeg({quality:94}).toFile(path.join(output.absolute,'preview_effects_'+name+'.jpg'));
  }
  return result.manifest;
}
if(require.main===module) {
  (async()=>{
    const settings=options(process.argv.slice(2));
    if(settings.help){console.log('node tools/paris_sprite_pipeline/build_effects.cjs [--inspect] [--source path.png] [--layout path.json] [--output project/directory]');return;}
    const manifest=await build(settings);
    console.log(JSON.stringify({valid:true,inspect_only:settings.inspect,source:manifest.source,atlas:manifest.atlas,
      animations:manifest.animation_order,rows:manifest.rows,maximum_boundary_alpha:Math.max(...manifest.frames.map(frame=>frame.source_boundary.maximum_alpha))},null,2));
  })().catch(error=>{console.error(error.message);process.exitCode=1;});
}
module.exports={ANIMATIONS,DURATIONS,ICON_ANIMATIONS,options,analyze,extractRaw,outputLocation,validateLayout,boundaryAlpha,packRaw,resourceText,iconResources,prepare,build};
