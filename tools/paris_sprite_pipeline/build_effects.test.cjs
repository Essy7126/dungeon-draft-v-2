'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const pipeline=require('./build_effects.cjs');
const sharp=require(process.env.SHARP_PATH||'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const ROOT=path.resolve(__dirname,'../..');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');

async function fixture(t,alteration='') {
  const base=path.resolve(os.tmpdir()),folder=fs.mkdtempSync(path.join(base,'paris-effects-test-'));
  t.after(()=>{
    const resolved=path.resolve(folder);
    assert.equal(path.dirname(resolved),base);assert.match(path.basename(resolved),/^paris-effects-test-/);
    fs.rmSync(resolved,{recursive:true,force:true});
  });
  const width=1024,height=2048,raw=Buffer.alloc(width*height*4),frames=[];
  for(let row=0;row<8;row++)for(let col=0;col<4;col++) {
    const left=col*256,top=row*256,size=[8,16,28,4][col];
    // Deliberately artificial byte fixtures, never used as game artwork.
    for(let y=124;y<124+size;y++)for(let x=112+col*2;x<112+col*2+size;x++) {
      const p=((top+y)*width+left+x)*4;
      raw[p]=180+row;raw[p+1]=64+col;raw[p+2]=144;raw[p+3]=255;
    }
    const spark=((top+128)*width+left+14)*4;
    raw[spark]=213;raw[spark+1]=47;raw[spark+2]=172;raw[spark+3]=1;
    frames.push({animation:pipeline.ANIMATIONS[row],frame:col,window:[left,top,256,256],anchor:[left+128,top+128],reviewed_boundary_alpha_max:0});
  }
  if(alteration==='opaque')for(let p=3;p<raw.length;p+=4)raw[p]=255;
  if(alteration==='border')raw[3]=1;
  if(alteration==='empty')for(let y=0;y<256;y++)raw.fill(0,y*width*4,(y*width+256)*4);
  const file=path.join(folder,'source.png');
  await sharp(raw,{raw:{width,height,channels:4}}).png().toFile(file);
  const layout={source_sha256:sha(fs.readFileSync(file)),source_size:[width,height],frames};
  return {file,raw,width,height,layout,folder};
}

test('all 32 RGBA windows preserve detached alpha1 and one scale per animation',async t=>{
  const input=await fixture(t),result=await pipeline.prepare(input.file,input.layout);
  assert.equal(result.manifest.frames.length,32);assert.equal(result.manifest.rows.length,8);
  assert.deepEqual(result.manifest.animation_order,['arrow','frost','fire','vortex','impact','whip','hellfire','transform']);
  assert.equal(result.manifest.processing.alpha_pixels_removed,0);
  assert.equal(result.manifest.processing.boundary_cleaning,false);
  const {data,info}=await sharp(result.atlas).raw().toBuffer({resolveWithObject:true});
  assert.deepEqual([info.width,info.height,info.channels],[1024,2048,4]);
  for(let index=0;index<32;index++) {
    const frame=result.manifest.frames[index];
    assert.equal(frame.source_alpha.alpha_histogram[1],1);
    assert.equal(frame.cropped_alpha_sum,frame.source_alpha.alpha_sum);
    assert.equal(result.manifest.rows[Math.floor(index/4)].common_scale,1);
    const source=pipeline.extractRaw(input.raw,input.width,frame.source_crop);
    const packed=pipeline.extractRaw(data,info.width,{left:index%4*256,top:Math.floor(index/4)*256,width:256,height:256});
    assert.ok(source.equals(packed),'At unit scale even every RGBA sample with alpha1 is byte-identical.');
    assert.equal(sha(packed),frame.packed_rgba_sha256);
  }
  for(const row of result.manifest.rows) {
    assert.equal(row.per_frame_recentering,false);assert.equal(row.per_frame_rescaling,false);
    assert.deepEqual(row.output_anchor,[128,128]);
  }
  const peak=result.manifest.frames[2],extinction=result.manifest.frames[3];
  assert.ok(extinction.packed_alpha.alpha_sum<peak.packed_alpha.alpha_sum/20,'Extinction stays visibly smaller, rather than being fitted to the peak.');
});

test('RGB and opaque baked backgrounds are rejected without synthesized alpha',async t=>{
  const input=await fixture(t),opaque=await fixture(t,'opaque');
  await assert.rejects(pipeline.prepare(opaque.file,opaque.layout),/native transparency/);
  const rgb=path.join(input.folder,'rgb.png');await sharp(input.file).removeAlpha().png().toFile(rgb);
  await assert.rejects(pipeline.prepare(rgb,input.layout),/native 8-bit RGBA/);
});

test('layout must be SHA-bound, dimension-matched and declare every ordered frame',async t=>{
  const input=await fixture(t),metadata={width:input.width,height:input.height};
  const hash=input.layout.source_sha256;
  for(const change of [l=>{l.source_sha256='stale';},l=>{l.source_size=[1024,1536];},l=>l.frames.pop(),l=>{l.frames[3].animation='arrow2';}]) {
    const layout=structuredClone(input.layout);change(layout);
    assert.throws(()=>pipeline.validateLayout(layout,metadata,hash));
  }
});

test('windows reject fractional coordinates, zero areas, out-of-bounds, overlap and gaps',async t=>{
  const input=await fixture(t),metadata={width:input.width,height:input.height},hash=input.layout.source_sha256;
  for(const window of [[0.5,0,256,256],[0,0,0,256],[-1,0,256,256],[0,0,2048,256],[0,0,257,256],[0,0,255,256]]) {
    const layout=structuredClone(input.layout);layout.frames[0].window=window;
    assert.throws(()=>pipeline.validateLayout(layout,metadata,hash));
  }
});

test('anchors and measured ceilings cannot be missing, nonfinite or out of bounds',async t=>{
  const input=await fixture(t),metadata={width:input.width,height:input.height},hash=input.layout.source_sha256;
  for(const anchor of [null,[],[NaN,128],[Infinity,128],[128.5,128],[256,128]]) {
    const layout=structuredClone(input.layout);layout.frames[0].anchor=anchor;
    assert.throws(()=>pipeline.validateLayout(layout,metadata,hash),/anchor/);
  }
  const layout=structuredClone(input.layout);layout.frames[0].reviewed_boundary_alpha_max=41;
  assert.throws(()=>pipeline.validateLayout(layout,metadata,hash),/ceiling/);
});

test('empty frames fail and unreviewed alpha boundaries fail without modifying source bytes',async t=>{
  const empty=await fixture(t,'empty'),border=await fixture(t,'border');
  await assert.rejects(pipeline.prepare(empty.file,empty.layout),/empty or invisible/);
  const before=fs.readFileSync(border.file);
  await assert.rejects(pipeline.prepare(border.file,border.layout),/unreviewed alpha 1/);
  border.layout.frames[0].reviewed_boundary_alpha_max=1;
  const result=await pipeline.prepare(border.file,border.layout);
  assert.equal(result.manifest.frames[0].source_boundary.pixels_removed,0);
  assert.equal(result.manifest.frames[0].source_boundary.maximum_alpha,1);
  assert.equal(result.manifest.frames[0].source_alpha.alpha_histogram[1],2);
  assert.equal(result.manifest.frames[0].source_alpha.alpha_sum,result.manifest.frames[0].cropped_alpha_sum);
  assert.ok(fs.readFileSync(border.file).equals(before));
});

test('SpriteFrames exposes 32 atlas regions and exactly eight non-looping clips',()=>{
  const text=pipeline.resourceText('res://effects.png');
  assert.match(text,/load_steps=34/);
  assert.equal((text.match(/\[sub_resource type="AtlasTexture"/g)||[]).length,32);
  assert.equal((text.match(/"loop": false/g)||[]).length,8);
  for(const name of pipeline.ANIMATIONS)assert.equal((text.match(new RegExp('"name": &"'+name+'"','g'))||[]).length,1);
  assert.match(text,/region = Rect2\(768, 1792, 256, 256\)/);
  assert.match(text,/"name": &"arrow",\n"speed": 20\.000000/);
  assert.match(text,/"name": &"transform",\n"speed": 4\.444444/);
});

test('eight spell icons plus transformation use authored frame2 without redraw or flip',()=>{
  const icons=pipeline.iconResources('res://effects.png');
  assert.equal(Object.keys(icons).length,9);
  for(const[id,animation]of Object.entries(pipeline.ICON_ANIMATIONS)) {
    assert.ok(icons[id].includes('region = Rect2(512, '+pipeline.ANIMATIONS.indexOf(animation)*256+', 256, 256)'));
    assert.equal((icons[id].match(/\[ext_resource /g)||[]).length,1);
    assert.ok(!icons[id].includes('flip')&&!icons[id].includes('rotation'));
  }
});

test('pack count, CLI and project-output boundaries fail explicitly',()=>{
  assert.throws(()=>pipeline.packRaw([]),/32 RGBA/);
  assert.throws(()=>pipeline.packRaw(Array(32).fill(Buffer.alloc(4))),/32 RGBA/);
  assert.throws(()=>pipeline.outputLocation('../outside'),/inside the project/);
  assert.throws(()=>pipeline.outputLocation('.git/effects'),/inside the project/);
  assert.throws(()=>pipeline.options(['--key-color','white']),/Unknown option/);
  assert.throws(()=>pipeline.options(['--source']),/requires a path/);
});

test('inspect leaves no output and failed input cannot replace an existing valid atlas',async t=>{
  const input=await fixture(t),layoutPath=path.join(input.folder,'layout.json');fs.writeFileSync(layoutPath,JSON.stringify(input.layout));
  const relative='artifacts/paris_fx_test_'+process.pid,absolute=path.join(ROOT,relative);
  assert.ok(!fs.existsSync(absolute));
  t.after(()=>{
    assert.equal(path.dirname(path.resolve(absolute)),path.join(ROOT,'artifacts'));assert.match(path.basename(absolute),/^paris_fx_test_\d+$/);
    fs.rmSync(absolute,{recursive:true,force:true});
  });
  const settings={source:input.file,layout:layoutPath,output:relative};
  await pipeline.build({...settings,inspect:true});assert.equal(fs.existsSync(absolute),false);
  await pipeline.build(settings);const previous=fs.readFileSync(path.join(absolute,'effects.png'));
  input.layout.frames[0].window[2]=255;fs.writeFileSync(layoutPath,JSON.stringify(input.layout));
  await assert.rejects(pipeline.build(settings),/unassigned/);
  assert.ok(previous.equals(fs.readFileSync(path.join(absolute,'effects.png'))));
});

test('production atlas is reproducible and all eight spell resources link their actual icons',async()=>{
  const source=path.join(ROOT,'art/source/vfx/paris/sprites_v1/source_effects.png');
  const output=path.join(ROOT,'assets/vfx/paris/sprites_v1');
  const manifest=JSON.parse(fs.readFileSync(path.join(output,'manifest.json'),'utf8'));
  const layout=JSON.parse(fs.readFileSync(path.join(__dirname,'effects_source_layout.json'),'utf8'));
  const result=await pipeline.prepare(source,layout);
  assert.ok(result.atlas.equals(fs.readFileSync(path.join(output,'effects.png'))));
  assert.equal(sha(result.atlas),manifest.atlas.sha256);
  const atlas='res://assets/vfx/paris/sprites_v1/effects.png';
  assert.equal(fs.readFileSync(path.join(output,'effects.tres'),'utf8'),pipeline.resourceText(atlas));
  for(const[id,text]of Object.entries(pipeline.iconResources(atlas))) {
    assert.equal(fs.readFileSync(path.join(output,'icons',id+'.tres'),'utf8'),text);
    if(id==='transformation')continue;
    const spell=fs.readFileSync(path.join(ROOT,'data/spells/enemies/paris',id+'.tres'),'utf8');
    assert.ok(spell.includes('path="res://assets/vfx/paris/sprites_v1/icons/'+id+'.tres" id="paris_icon"'));
    assert.ok(spell.includes('icon = ExtResource("paris_icon")'));
  }
});
