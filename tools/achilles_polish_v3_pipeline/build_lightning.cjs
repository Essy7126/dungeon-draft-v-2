#!/usr/bin/env node
'use strict';
// Mechanical preparation only: preserve authored lightning, native alpha,
// phase sizes and one uniform scale per row; never synthesize effect drawings.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const {cutoutRaw}=require('./build_effects.cjs');
const {analyze,extractRaw}=require('../achilles_kit_sprite_pipeline/build_effects.cjs');
const ROOT=path.resolve(__dirname,'../..'),SIZE=256,INNER=232,MARGIN=12;
const SOURCE='art/source/vfx/achilles_polish_v3/source_lightning.png';
const OUTPUT='assets/vfx/achilles_polish_v3';
const sha=v=>crypto.createHash('sha256').update(v).digest('hex');
function borderAlpha(raw,w,h){let n=0;for(let y=0;y<h;y++)for(let x=0;x<w;x++)if(!x||!y||x===w-1||y===h-1)n=Math.max(n,raw[(y*w+x)*4+3]);return n;}
async function prepare(layout){
 const bytes=fs.readFileSync(path.join(ROOT,SOURCE)),meta=await sharp(bytes).metadata();
 if(layout.reviewed!==true||layout.sha256!==sha(bytes)||meta.width!==layout.size[0]||meta.height!==layout.size[1])throw Error('Reviewed lightning source mismatch');
 const decoded=await sharp(bytes).ensureAlpha().raw().toBuffer(),cut=cutoutRaw(decoded,meta.width,meta.height,layout.background);
 if(layout.frames.length!==8)throw Error('Eight authored source frames required');
 const coverage=new Uint8Array(meta.width*meta.height),frames=[];
 for(let i=0;i<8;i++){
  const f=layout.frames[i],row=Math.floor(i/4),name=row?'impact_lightning':'arrow_lightning';
  if(f.animation!==name||f.frame!==i%4)throw Error('Unexpected frame order');
  const [x,y,w,h]=f.window;
  if(!f.window.every(Number.isInteger)||x<0||y<0||w<=0||h<=0||x+w>meta.width||y+h>meta.height)throw Error('Invalid source window');
  for(let yy=y;yy<y+h;yy++)for(let xx=x;xx<x+w;xx++)if(coverage[yy*meta.width+xx]++)throw Error('Overlapping windows');
  const raw=extractRaw(cut.raw,meta.width,{left:x,top:y,width:w,height:h}),stats=analyze(raw,w,h),border=borderAlpha(raw,w,h);
  if(!stats.alpha_bounds.core||border>f.boundary_alpha_max||f.boundary_alpha_max>5)throw Error('Unreviewed or clipped lightning edge');
  const anchor=[f.anchor[0]-x,f.anchor[1]-y],radius=layout.common_radii[row];
  if(!Number.isInteger(radius)||radius<1||anchor[0]<0||anchor[1]<0||anchor[0]>=w||anchor[1]>=h)throw Error('Invalid explicit anchor/radius');
  const square=extractRaw(raw,w,{left:anchor[0]-radius,top:anchor[1]-radius,width:radius*2,height:radius*2});
  if(analyze(square,radius*2,radius*2).alpha_sum!==stats.alpha_sum)throw Error('Anchor crop discarded authored alpha');
  const scaled=await sharp(square,{raw:{width:radius*2,height:radius*2,channels:4}}).resize(INNER,INNER,{kernel:'lanczos3'}).raw().toBuffer();
  const packed=Buffer.alloc(SIZE*SIZE*4);for(let yy=0;yy<INNER;yy++)scaled.copy(packed,((yy+MARGIN)*SIZE+MARGIN)*4,yy*INNER*4,(yy+1)*INNER*4);
  frames.push({...f,source_alpha:stats,source_boundary_alpha:border,scale:INNER/(radius*2),source_rgba_sha256:sha(raw),packed_rgba_sha256:sha(packed),packed});
 }
 if(!coverage.every(v=>v===1)||frames.reduce((n,f)=>n+f.source_alpha.alpha_sum,0)!==cut.report.output_alpha_sum)throw Error('Source pixels not assigned exactly once');
 const atlas=Buffer.alloc(1024*512*4);for(let i=0;i<8;i++)for(let y=0;y<SIZE;y++)frames[i].packed.copy(atlas,((Math.floor(i/4)*SIZE+y)*1024+(i%4)*SIZE)*4,y*SIZE*4,(y+1)*SIZE*4);
 const png=await sharp(atlas,{raw:{width:1024,height:512,channels:4}}).png().toBuffer(),roundtrip=await sharp(png).raw().toBuffer();
 for(let i=0;i<8;i++){const actual=extractRaw(roundtrip,1024,{left:i%4*SIZE,top:Math.floor(i/4)*SIZE,width:SIZE,height:SIZE});if(sha(actual)!==frames[i].packed_rgba_sha256)throw Error('Atlas roundtrip mismatch');}
 let resource='[gd_resource type="SpriteFrames" load_steps=10 format=3]\n\n[ext_resource type="Texture2D" path="res://'+OUTPUT+'/lightning.png" id="1_atlas"]\n\n';
 for(let i=0;i<8;i++)resource+='[sub_resource type="AtlasTexture" id="Lightning_'+i+'"]\natlas = ExtResource("1_atlas")\nregion = Rect2('+[i%4*SIZE,Math.floor(i/4)*SIZE,SIZE,SIZE].join(', ')+')\nfilter_clip = true\n\n';
 resource+='[resource]\nanimations = [';
 for(let row=0;row<2;row++){if(row)resource+=', ';resource+='{\n"frames": [';for(let i=0;i<4;i++){if(i)resource+=', ';resource+='{\n"duration": 1.0,\n"texture": SubResource("Lightning_'+(row*4+i)+'")\n}';}resource+='],\n"loop": false,\n"name": &"'+(row?'impact_lightning':'arrow_lightning')+'",\n"speed": '+(row?'18.1818181818':'20.0')+'\n}';}resource+=']\n';
 const manifest={schema_version:1,source:SOURCE,source_sha256:sha(bytes),dimensions:[meta.width,meta.height],source_alpha:cut.report,source_generator:'OpenAI ImageGen',background_removal_authorized_by_user:true,atlas:OUTPUT+'/lightning.png',atlas_sha256:sha(png),canvas:[SIZE,SIZE],pivot:[128,128],common_radii:layout.common_radii,frames:frames.map(({packed,...f})=>f),pixel_policy:'Native alpha retained, including reviewed boundary alpha <=5; every original pixel belongs to exactly one source window. Uniform scale per row, no per-phase fitting, no rotation/mirroring/drawing. Packed atlas is verified byte-for-byte after PNG decode.'};
 return {png,resource,manifest,frames};
}
async function build(layout,write=true){
 const out=await prepare(layout);
 if(write){const dir=path.join(ROOT,OUTPUT);fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'lightning.png'),out.png);fs.writeFileSync(path.join(dir,'lightning.tres'),out.resource);fs.writeFileSync(path.join(dir,'lightning_manifest.json'),JSON.stringify(out.manifest,null,2)+'\n');}
 return out;
}
if(require.main===module){build(JSON.parse(fs.readFileSync(path.join(__dirname,'lightning_layout.json'),'utf8')),!process.argv.includes('--inspect')).then(r=>console.log(JSON.stringify({frames:r.frames.length,atlas_sha256:r.manifest.atlas_sha256,native_alpha_sum:r.manifest.source_alpha.output_alpha_sum}))).catch(e=>{console.error(e.stack);process.exitCode=1;});}
module.exports={prepare,build,borderAlpha};
