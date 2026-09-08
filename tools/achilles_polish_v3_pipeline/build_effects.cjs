#!/usr/bin/env node
'use strict';
// Mechanical sprite preparation. Artwork is supplied by image generation;
// source RGBA is never painted, rotated, mirrored or morphed by this script.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {analyze,extractRaw,outputLocation}=require('../achilles_kit_sprite_pipeline/build_effects.cjs');
let sharp;try{sharp=require('sharp');}catch{sharp=require(process.env.SHARP_PATH||
  'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const ROOT=path.resolve(__dirname,'../..');
const OUTPUT='assets/vfx/achilles_polish_v3';
const SOURCE='art/source/vfx/achilles_polish_v3';
const VARIANTS=['base','reach','heavy','piercing','death_line','volley'];
const NEW_CLIPS=['arrow','arrow_reach','arrow_heavy','arrow_piercing','arrow_death_line','arrow_volley',
  'impact','impact_reach','impact_heavy','impact_piercing','impact_death_line','impact_volley'];
const LEGACY_CLIPS=['sweep','guard','dust','barrier'];
const LEGACY_ATLAS='assets/vfx/achilles_kit_v2/effects.png';
const SIZE=256,MARGIN=12,INNER=232,COLS=4;
const sha=v=>crypto.createHash('sha256').update(v).digest('hex');
const relative=p=>path.relative(ROOT,p).split(path.sep).join('/');
const clone=v=>JSON.parse(JSON.stringify(v));

function boundaryAlpha(raw,width,height){
  let maximum_alpha=0,nonzero_pixels=0;
  for(let y=0;y<height;y++)for(let x=0;x<width;x++)if(!x||!y||x===width-1||y===height-1){
    const a=raw[(y*width+x)*4+3];maximum_alpha=Math.max(maximum_alpha,a);if(a)nonzero_pixels++;
  }
  return {maximum_alpha,nonzero_pixels};
}

function cutoutRaw(raw,width,height,background){
  if(!background||!['native','magenta'].includes(background.mode))throw Error('Explicit native or magenta background mode required.');
  const output=Buffer.from(raw);
  const before=analyze(raw,width,height);
  const report={mode:background.mode,source_alpha_sum:before.alpha_sum,removed_pixels:0,
    feathered_pixels:0,foreground_pixels_changed:0,unmatte_rgb:false};
  if(background.mode==='native'){
    if(before.transparent_pixels<width*height*.2)throw Error('Native source has insufficient true alpha; no automatic checker removal.');
    report.output_alpha_sum=before.alpha_sum;
    return {raw:output,report};
  }
  // Magenta keying is opt-in and limited to a declared absent-from-art color.
  // Distance feathering removes antialiased matte contamination at the edge.
  const rgb=background.rgb||[255,0,255];
  const hard=background.solid_distance??20,soft=background.feather_distance??80;
  if(!Array.isArray(rgb)||rgb.length!==3||!rgb.every(Number.isInteger)||rgb.some(n=>n<0||n>255)||
    rgb[0]<180||rgb[1]>80||rgb[2]<180||hard<0||hard>50||soft<=hard||soft>120)
    throw Error('Magenta key parameters outside the reviewed bounds.');
  for(let p=0;p<raw.length;p+=4){
    if(!raw[p+3])continue;
    const distance=Math.max(Math.abs(raw[p]-rgb[0]),Math.abs(raw[p+1]-rgb[1]),Math.abs(raw[p+2]-rgb[2]));
    if(distance>=soft)continue;
    const coverage=Math.max(0,(distance-hard)/(soft-hard));
    const alpha=Math.round(raw[p+3]*coverage);
    if(alpha===0){output[p+3]=0;report.removed_pixels++;}
    else{
      output[p+3]=alpha;report.feathered_pixels++;
      for(let c=0;c<3;c++)output[p+c]=Math.max(0,Math.min(255,Math.round((raw[p+c]-(1-coverage)*rgb[c])/coverage)));
    }
  }
  if(report.removed_pixels<width*height*.2)throw Error('Declared magenta matte not sufficiently present; refuse ambiguous keying.');
  report.unmatte_rgb=true;report.key_rgb=rgb;report.solid_distance=hard;report.feather_distance=soft;
  report.output_alpha_sum=analyze(output,width,height).alpha_sum;
  return {raw:output,report};
}

function validateLayout(layout,metadata,sourceHash,prefix){
  if(!layout||layout.reviewed!==true)throw Error('Source layout must be explicitly reviewed.');
  if(layout.sha256!==sourceHash)throw Error('Source SHA mismatch: remeasure the layout.');
  if(!Array.isArray(layout.size)||layout.size[0]!==metadata.width||layout.size[1]!==metadata.height)
    throw Error('Source dimensions mismatch.');
  if(!Array.isArray(layout.frames)||layout.frames.length!==24)throw Error('Exactly 24 source windows required.');
  const coverage=new Uint8Array(metadata.width*metadata.height);
  const result=layout.frames.map((frame,index)=>{
    const variant=VARIANTS[Math.floor(index/4)],animation=variant==='base'?prefix:prefix+'_'+variant;
    if(frame.animation!==animation||frame.frame!==index%4)throw Error('Unexpected ordered clip '+index+'.');
    const box=frame.window,anchor=frame.anchor,ceiling=frame.boundary_alpha_max??0;
    if(!Array.isArray(box)||box.length!==4||!box.every(Number.isInteger)||box[0]<0||box[1]<0||
      box[2]<=0||box[3]<=0||box[0]+box[2]>metadata.width||box[1]+box[3]>metadata.height)
      throw Error('Invalid source window '+animation+'['+frame.frame+'].');
    if(!Array.isArray(anchor)||anchor.length!==2||!anchor.every(Number.isInteger)||
      anchor[0]<box[0]||anchor[1]<box[1]||anchor[0]>=box[0]+box[2]||anchor[1]>=box[1]+box[3])
      throw Error('Explicit anchor missing or outside its window.');
    if(!Number.isInteger(ceiling)||ceiling<0||ceiling>40)throw Error('Boundary alpha ceiling must be reviewed in 0..40.');
    for(let y=box[1];y<box[1]+box[3];y++)for(let x=box[0];x<box[0]+box[2];x++)
      if(coverage[y*metadata.width+x]++)throw Error('Source windows overlap.');
    return {animation,frame:frame.frame,crop:{left:box[0],top:box[1],width:box[2],height:box[3]},
      anchor:[anchor[0]-box[0],anchor[1]-box[1]],global_anchor:anchor.slice(),boundary_alpha_max:ceiling};
  });
  if(!coverage.every(v=>v===1))throw Error('Source windows leave unassigned pixels.');
  return result;
}

async function prepareSheet(sourcePath,layout,prefix){
  const bytes=fs.readFileSync(sourcePath),metadata=await sharp(bytes).metadata();
  if(metadata.format!=='png'||metadata.depth!=='uchar'||(metadata.orientation&&metadata.orientation!==1))
    throw Error('Upright 8-bit PNG source required.');
  if(layout.background?.mode==='native'&&(!metadata.hasAlpha||metadata.channels!==4))
    throw Error('Native mode requires real RGBA source.');
  const decoded=await sharp(bytes).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const cut=cutoutRaw(decoded.data,decoded.info.width,decoded.info.height,layout.background);
  const declared=validateLayout(layout,metadata,sha(bytes),prefix),frames=[];
  let radius=0;
  for(const cell of declared){
    const raw=extractRaw(cut.raw,metadata.width,cell.crop),alpha=analyze(raw,cell.crop.width,cell.crop.height);
    const border=boundaryAlpha(raw,cell.crop.width,cell.crop.height);
    if(!alpha.alpha_bounds.core)throw Error(cell.animation+'['+cell.frame+']: empty or invisible.');
    if(border.maximum_alpha>cell.boundary_alpha_max)throw Error(cell.animation+'['+cell.frame+']: unreviewed boundary alpha '+border.maximum_alpha);
    const b=alpha.alpha_bounds.all,[x,y]=cell.anchor;
    radius=Math.max(radius,x-b[0],y-b[1],b[2]-x,b[3]-y);
    frames.push({...cell,raw,source_rgba_sha256:sha(extractRaw(decoded.data,metadata.width,cell.crop)),
      prepared_rgba_sha256:sha(raw),prepared_alpha:alpha,source_boundary:border});
  }
  if(frames.reduce((n,f)=>n+f.prepared_alpha.alpha_sum,0)!==cut.report.output_alpha_sum)
    throw Error('Prepared alpha assignment lost or duplicated pixels.');
  // One scale per source sheet, shared by all 6 variants and all 4 phases.
  // In particular, extinction is never individually fitted to maximum size.
  radius=Math.ceil(radius+2);
  if(layout.common_radius!==undefined){
    if(!Number.isInteger(layout.common_radius)||layout.common_radius<radius)throw Error('Explicit common radius would clip source pixels.');
    radius=layout.common_radius;
  }
  const side=radius*2,scale=INNER/side,packed=[];
  for(const frame of frames){
    const crop={left:frame.anchor[0]-radius,top:frame.anchor[1]-radius,width:side,height:side};
    const source=extractRaw(frame.raw,frame.crop.width,crop);
    if(analyze(source,side,side).alpha_sum!==frame.prepared_alpha.alpha_sum)throw Error('Anchor crop discarded alpha.');
    const resized=side===INNER?source:await sharp(source,{raw:{width:side,height:side,channels:4}})
      .resize(INNER,INNER,{kernel:'lanczos3'}).raw().toBuffer();
    const output=Buffer.alloc(SIZE*SIZE*4);
    for(let y=0;y<INNER;y++)resized.copy(output,((y+MARGIN)*SIZE+MARGIN)*4,y*INNER*4,(y+1)*INNER*4);
    const alpha=analyze(output,SIZE,SIZE);
    if(!alpha.alpha_bounds.all||Math.min(...alpha.margins.all)<MARGIN)throw Error('Packed art touches the atlas boundary.');
    packed.push(output);
    frame.common_anchor_crop=crop;frame.output_anchor=[128,128];frame.packed_alpha=alpha;
    frame.packed_rgba_sha256=sha(output);delete frame.raw;
  }
  return {packed,manifest:{path:relative(sourcePath),sha256:sha(bytes),size:[metadata.width,metadata.height],
    native_alpha:metadata.hasAlpha,background:cut.report,layout:clone(layout),
    common_radius:radius,common_scale:scale,per_frame_rescaling:false,per_frame_recentering:false,
    per_variant_rescaling:false,frames}};
}

function packRaw(frames){
  if(frames.length!==48||frames.some(f=>!Buffer.isBuffer(f)||f.length!==SIZE*SIZE*4))throw Error('Expected 48 RGBA frames.');
  const raw=Buffer.alloc(1024*3072*4);
  frames.forEach((frame,index)=>{
    for(let y=0;y<SIZE;y++)frame.copy(raw,(((Math.floor(index/4)*SIZE+y)*1024+index%4*SIZE)*4),y*SIZE*4,(y+1)*SIZE*4);
  });
  return raw;
}

function resourceText(atlasPath,legacyPath='res://'+LEGACY_ATLAS){
  const blocks=['[gd_resource type="SpriteFrames" load_steps=67 format=3]',
    '[ext_resource type="Texture2D" path="'+atlasPath+'" id="1_atlas"]',
    '[ext_resource type="Texture2D" path="'+legacyPath+'" id="2_legacy"]'];
  const names=[...NEW_CLIPS,...LEGACY_CLIPS];
  names.forEach((name,index)=>{
    const legacy=index>=12,row=legacy?index-10:index;
    for(let frame=0;frame<4;frame++)blocks.push('[sub_resource type="AtlasTexture" id="Frame_'+name+'_'+frame+'"]\n'+
      'atlas = ExtResource("'+(legacy?'2_legacy':'1_atlas')+'")\nregion = Rect2('+frame*SIZE+', '+row*SIZE+', 256, 256)');
  });
  const entries=names.map(name=>'{\n"frames": ['+Array.from({length:4},(_,frame)=>'{\n"duration": 1.0,\n'+
    '"texture": SubResource("Frame_'+name+'_'+frame+'")\n}').join(', ')+'],\n"loop": false,\n"name": &"'+name+
    '",\n"speed": '+(name.startsWith('arrow')?20:name.startsWith('impact')?4/.22:4/.24).toFixed(6)+'\n}');
  blocks.push('[resource]\nanimations = ['+entries.join(', ')+']');
  return blocks.join('\n\n')+'\n';
}

async function build(settings={}){
  const layoutPath=path.resolve(ROOT,settings.layout||path.join(__dirname,'effects_layout.json'));
  const layoutBytes=fs.readFileSync(layoutPath),layout=JSON.parse(layoutBytes.toString('utf8').replace(/^\uFEFF/,''));
  if(layout.schema_version!==1)throw Error('Unknown layout schema.');
  const projectiles=await prepareSheet(path.resolve(ROOT,layout.projectiles.source_path),layout.projectiles,'arrow');
  const impacts=await prepareSheet(path.resolve(ROOT,layout.impacts.source_path),layout.impacts,'impact');
  const packed=[...projectiles.packed,...impacts.packed],atlasRaw=packRaw(packed);
  const atlas=await sharp(atlasRaw,{raw:{width:1024,height:3072,channels:4}}).png().toBuffer();
  const decoded=await sharp(atlas).raw().toBuffer();
  for(let index=0;index<48;index++){
    const raw=extractRaw(decoded,1024,{left:index%4*SIZE,top:Math.floor(index/4)*SIZE,width:SIZE,height:SIZE});
    if(!raw.equals(packed[index]))throw Error('Atlas PNG round-trip altered frame '+index);
  }
  const legacy=fs.readFileSync(path.join(ROOT,LEGACY_ATLAS)),legacyMetadata=await sharp(legacy).metadata();
  if(legacyMetadata.width!==1024||legacyMetadata.height!==1536)throw Error('Legacy atlas geometry changed.');
  const output=outputLocation(settings.output||OUTPUT);
  const manifest={schema_version:3,complete:true,authored_frames:48,total_runtime_clips:16,
    animation_order:[...NEW_CLIPS,...LEGACY_CLIPS],frames_per_animation:4,
    sources:{projectiles:projectiles.manifest,impacts:impacts.manifest},
    layout:{path:relative(layoutPath),sha256:sha(layoutBytes)},
    atlas:{path:output.relative+'/effects.png',sha256:sha(atlas),size:[1024,3072],frame_size:[256,256],anchor:[128,128]},
    inherited:{path:LEGACY_ATLAS,sha256:sha(legacy),clips:LEGACY_CLIPS,
      regions:LEGACY_CLIPS.map((name,index)=>({animation:name,regions:Array.from({length:4},(_,i)=>[i*SIZE,(index+2)*SIZE,SIZE,SIZE])})),
      pixels_modified:false,source_file_rewritten:false},
    processing:{pixel_redraw:false,rotation:false,mirroring:false,per_frame_rescaling:false,
      per_variant_rescaling:false,native_alpha_preserved:layout.projectiles.background.mode==='native'&&layout.impacts.background.mode==='native',
      explicit_user_authorized_matte_removal:true,all_prepared_pixels_assigned_once:true,padding:12,
      interpolation:'Lanczos3 RGBA',atlas_roundtrip_verified_frames:48},sharp_version:sharp.versions.sharp};
  if(!settings.inspect){
    fs.mkdirSync(output.absolute,{recursive:true});
    fs.writeFileSync(path.join(output.absolute,'effects.png'),atlas);
    fs.writeFileSync(path.join(output.absolute,'effects.tres'),resourceText('res://'+manifest.atlas.path));
    fs.writeFileSync(path.join(output.absolute,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
    const review=outputLocation('artifacts/achilles_polish_v3/effects_review');
    fs.mkdirSync(review.absolute,{recursive:true});
    for(const[name,background]of [['gray','#626971'],['dark','#192128'],['light','#e8e3d5']])
      await sharp(atlas).flatten({background}).jpeg({quality:92}).toFile(path.join(review.absolute,name+'.jpg'));
  }
  return manifest;
}

function options(argv){
  const result={inspect:false};
  for(let index=0;index<argv.length;index++){
    const key=argv[index];
    if(key==='--inspect')result.inspect=true;
    else if(['--layout','--output'].includes(key)){const value=argv[++index];if(!value||value.startsWith('--'))throw Error(key+' requires path.');result[key.slice(2)]=value;}
    else throw Error('Unknown option '+key);
  }
  return result;
}
if(require.main===module)build(options(process.argv.slice(2))).then(m=>console.log(JSON.stringify({
  complete:m.complete,authored_frames:m.authored_frames,runtime_clips:m.total_runtime_clips,atlas:m.atlas,
  projectile_scale:m.sources.projectiles.common_scale,impact_scale:m.sources.impacts.common_scale
},null,2))).catch(e=>{console.error(e.stack);process.exitCode=1;});
module.exports={ROOT,SOURCE,OUTPUT,VARIANTS,NEW_CLIPS,LEGACY_CLIPS,SIZE,sha,analyze,extractRaw,boundaryAlpha,cutoutRaw,
  validateLayout,prepareSheet,packRaw,resourceText,build,options};
