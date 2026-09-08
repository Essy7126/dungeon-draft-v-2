'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const p=require('./build_effects.cjs');
const sharp=require(process.env.SHARP_PATH||'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');

async function fixture(t,mode='native'){
  const parent=path.resolve(os.tmpdir()),folder=fs.mkdtempSync(path.join(parent,'achilles-fx-v3-test-'));
  t.after(()=>{const target=path.resolve(folder);assert.equal(path.dirname(target),parent);assert.match(path.basename(target),/^achilles-fx-v3-test-/);fs.rmSync(target,{recursive:true,force:true});});
  const width=1024,height=1536,raw=Buffer.alloc(width*height*4),frames=[];
  if(mode==='magenta')for(let i=0;i<raw.length;i+=4){raw[i]=255;raw[i+2]=255;raw[i+3]=255;}
  for(let row=0;row<6;row++)for(let col=0;col<4;col++){
    const left=col*256,top=row*256,size=[8,14,22,4][col];
    // Artificial byte fixtures for image mechanics, never exported as game art.
    for(let y=120;y<120+size;y++)for(let x=120;x<120+size;x++){
      const i=((top+y)*width+left+x)*4;raw[i]=201+row;raw[i+1]=170;raw[i+2]=80;raw[i+3]=255;
    }
    if(mode==='native'){const i=((top+128)*width+left+14)*4;raw[i]=180;raw[i+1]=90;raw[i+2]=20;raw[i+3]=1;}
    frames.push({animation:row?'arrow_'+p.VARIANTS[row]:'arrow',frame:col,window:[left,top,256,256],
      anchor:[left+128,top+128],boundary_alpha_max:0});
  }
  const file=path.join(folder,'sheet.png');await sharp(raw,{raw:{width,height,channels:4}}).png().toFile(file);
  return {file,folder,raw,width,height,layout:{reviewed:true,sha256:p.sha(fs.readFileSync(file)),size:[width,height],
    background:{mode},frames}};
}

test('native RGBA preserves all pixels before resampling and shares one scale across variants',async t=>{
  const input=await fixture(t),before=fs.readFileSync(input.file),result=await p.prepareSheet(input.file,input.layout,'arrow');
  assert.equal(result.packed.length,24);
  assert.equal(result.manifest.common_scale,1);
  assert.equal(result.manifest.background.removed_pixels,0);
  assert.equal(result.manifest.background.source_alpha_sum,result.manifest.background.output_alpha_sum);
  for(let i=0;i<24;i++){
    const frame=result.manifest.frames[i],source=p.extractRaw(input.raw,input.width,frame.crop);
    assert.equal(frame.prepared_alpha.alpha_histogram[1],1);
    assert.ok(source.equals(result.packed[i]),'At unit scale each RGBA byte, including alpha1, survives exactly.');
    assert.deepEqual(frame.output_anchor,[128,128]);
  }
  assert.ok(result.manifest.frames[3].packed_alpha.alpha_sum<result.manifest.frames[2].packed_alpha.alpha_sum/20);
  assert.ok(fs.readFileSync(input.file).equals(before));
});

test('explicit magenta removal leaves gold foreground intact and accounts for the matte',async t=>{
  const input=await fixture(t,'magenta'),result=await p.prepareSheet(input.file,input.layout,'arrow');
  assert.ok(result.manifest.background.removed_pixels>input.width*input.height*.9);
  assert.equal(result.manifest.background.feathered_pixels,0);
  assert.equal(result.manifest.background.unmatte_rgb,true);
  const native=p.cutoutRaw(input.raw,input.width,input.height,{mode:'magenta'});
  const inside=((123)*input.width+123)*4;
  assert.deepEqual([...native.raw.subarray(inside,inside+4)],[201,170,80,255]);
  assert.equal(native.raw[3],0);
  assert.equal(input.raw[3],255,'Cutout does not mutate the supplied source buffer.');
});

test('alpha synthesis is never silently applied to native or unknown backgrounds',async t=>{
  const input=await fixture(t,'magenta');
  await assert.rejects(p.prepareSheet(input.file,{...input.layout,background:{mode:'native'}},'arrow'),/true alpha/);
  assert.throws(()=>p.cutoutRaw(input.raw,input.width,input.height,{mode:'checker'}),/Explicit native or magenta/);
  assert.throws(()=>p.cutoutRaw(Buffer.alloc(16*16*4,255),16,16,{mode:'magenta'}),/matte not sufficiently/);
  assert.throws(()=>p.cutoutRaw(input.raw,input.width,input.height,{mode:'magenta',solid_distance:200}),/outside/);
});

test('SHA-bound layout rejects changed sources, dimensions, order, gaps and overlaps',async t=>{
  const input=await fixture(t),meta={width:input.width,height:input.height};
  for(const change of [l=>l.reviewed=false,l=>l.sha256='stale',l=>l.size=[12,34],l=>l.frames.pop(),
    l=>l.frames[0].animation='wrong',l=>l.frames[0].window=[0,0,257,256],
    l=>l.frames[0].window=[0,0,255,256],l=>l.frames[0].anchor=[-1,0],
    l=>l.frames[0].boundary_alpha_max=255]){
    const layout=structuredClone(input.layout);change(layout);
    assert.throws(()=>p.validateLayout(layout,meta,input.layout.sha256,'arrow'));
  }
});

test('strict boundaries reject a clipped visible core even with a valid new source hash',async t=>{
  const input=await fixture(t);input.raw[3]=255;
  await sharp(input.raw,{raw:{width:input.width,height:input.height,channels:4}}).png().toFile(input.file);
  input.layout.sha256=p.sha(fs.readFileSync(input.file));
  await assert.rejects(p.prepareSheet(input.file,input.layout,'arrow'),/unreviewed boundary alpha 255/);
  input.raw[3]=1;await sharp(input.raw,{raw:{width:input.width,height:input.height,channels:4}}).png().toFile(input.file);
  input.layout.sha256=p.sha(fs.readFileSync(input.file));input.layout.frames[0].boundary_alpha_max=1;
  const prepared=await p.prepareSheet(input.file,input.layout,'arrow');
  assert.equal(prepared.manifest.frames[0].source_boundary.maximum_alpha,1);
  assert.equal(prepared.manifest.background.removed_pixels,0);
});

test('48-cell raw packing is byte-exact in every atlas region',()=>{
  const frames=Array.from({length:48},(_,i)=>Buffer.alloc(256*256*4,i));
  const atlas=p.packRaw(frames);
  for(let i=0;i<48;i++)assert.ok(p.extractRaw(atlas,1024,{left:i%4*256,top:Math.floor(i/4)*256,width:256,height:256}).equals(frames[i]));
  assert.throws(()=>p.packRaw(frames.slice(1)),/48/);
});

test('runtime resource contains all 16 clips and retains the exact four old atlas rows',()=>{
  const text=p.resourceText('res://assets/vfx/achilles_polish_v3/effects.png');
  assert.equal((text.match(/\[sub_resource type="AtlasTexture"/g)||[]).length,64);
  assert.equal((text.match(/"loop": false/g)||[]).length,16);
  for(const name of [...p.NEW_CLIPS,...p.LEGACY_CLIPS])assert.ok(text.includes('"name": &"'+name+'"'));
  p.LEGACY_CLIPS.forEach((name,index)=>{
    for(let f=0;f<4;f++)assert.ok(text.includes('[sub_resource type="AtlasTexture" id="Frame_'+name+'_'+f+'"]\natlas = ExtResource("2_legacy")\nregion = Rect2('+f*256+', '+(index+2)*256+', 256, 256)'));
  });
  assert.match(text,/load_steps=67/);
});

test('delivered art is reproducible, alpha accounted and legacy atlas unmodified',async()=>{
  const manifestPath=path.join(p.ROOT,p.OUTPUT,'manifest.json');
  assert.ok(fs.existsSync(manifestPath),'Production assets must exist; no skipped asset verification.');
  const delivered=JSON.parse(fs.readFileSync(manifestPath)),rebuilt=await p.build({inspect:true});
  assert.equal(rebuilt.atlas.sha256,delivered.atlas.sha256);
  assert.equal(rebuilt.inherited.sha256,delivered.inherited.sha256);
  assert.equal(rebuilt.authored_frames,48);
  assert.equal(rebuilt.total_runtime_clips,16);
  assert.equal(rebuilt.sources.projectiles.background.removed_pixels,0);
  assert.equal(rebuilt.sources.impacts.background.mode,'magenta');
  assert.ok(rebuilt.sources.impacts.background.removed_pixels>0);
  assert.ok(rebuilt.sources.impacts.frames.every(f=>f.source_boundary.maximum_alpha===0));
  assert.ok(rebuilt.sources.projectiles.frames.every(f=>f.source_boundary.maximum_alpha<=1));
  assert.equal(fs.readFileSync(path.join(p.ROOT,p.OUTPUT,'effects.tres'),'utf8'),p.resourceText('res://'+delivered.atlas.path));
});
