'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const build = require('./build.cjs');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const ROOT = path.resolve(__dirname, '../..');
const OUTPUT = path.join(ROOT, 'assets/characters/paris/sprites_v1');
const DIRS = ['E','N','S','W'];
const STEMS = ['idle','walk','attack','cast','hit','death'];
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const items = form => ['E','N'].map(direction => ({key:`${form}_${direction}`,frames:Array.from({length:16},(_,index)=>({index}))}));

// These deliberately artificial RGBA blocks exercise extraction and atlas
// copying only. They are held in memory, never written into game artwork.
function syntheticRGBA(count=16) {
  const width=256,height=count/4*64,raw=Buffer.alloc(width*height*4),roots=[];
  for(let index=0;index<count;index++) {
    const x0=index%4*64+20,y0=Math.floor(index/4)*64+16;
    roots.push([x0+12,y0+24]);
    for(let y=y0;y<y0+24;y++) for(let x=x0;x<x0+24;x++) {
      const p=(y*width+x)*4;
      raw[p]=40+index*7;raw[p+1]=80;raw[p+2]=160;raw[p+3]=255;
    }
    // The low-alpha sample must survive the crop even though it lies outside
    // the alpha>24 bounding box used for visual core measurements.
    const halo=((y0-2)*width+x0-2)*4;
    raw[halo]=219;raw[halo+1]=33;raw[halo+2]=95;raw[halo+3]=1;
  }
  return {width,height,raw,roots};
}

async function withSource(bytes,run,key='fixture') {
  assert.equal(typeof build.inspect,'function','The inspect function must be exported for isolated source validation.');
  const fixturePath=path.join(ROOT,`art/source/characters/paris/sprites_v1/source_${key}.png`);
  const original=fs.readFileSync;
  fs.readFileSync=function(p,...args) {
    if(typeof p==='string' && path.resolve(p)===fixturePath) return bytes;
    return original.call(fs,p,...args);
  };
  try {return await run();} finally {fs.readFileSync=original;}
}

async function inspectedFixture(count=16,key='fixture') {
  const fixture=syntheticRGBA(count);
  const bytes=await sharp(fixture.raw,{raw:{width:fixture.width,height:fixture.height,channels:4}}).png().toBuffer();
  const inspected=await withSource(bytes,()=>build.inspect(key),key);
  return {fixture,inspected};
}

test('an opaque RGBA sheet and an RGB sheet are rejected as native transparency failures',async()=>{
  const rgba=await sharp({create:{width:256,height:256,channels:4,background:{r:160,g:160,b:160,alpha:1}}}).png().toBuffer();
  await withSource(rgba,()=>assert.rejects(build.inspect('fixture'),/native transparency|alpha|opaque/i));
  const rgb=await sharp(rgba).removeAlpha().png().toBuffer();
  await withSource(rgb,()=>assert.rejects(build.inspect('fixture'),/native transparency|alpha|opaque/i));
});

test('the sixteen windows partition odd-size source dimensions without gaps or overlap',()=>{
  const width=259,height=263,coverage=new Uint8Array(width*height);
  const windows=build.windows(width,height);
  assert.equal(windows.length,16);
  for(const [left,top,w,h]of windows) {
    assert(w>0&&h>0&&left>=0&&top>=0&&left+w<=width&&top+h<=height);
    for(let y=top;y<top+h;y++) for(let x=left;x<left+w;x++) coverage[y*width+x]++;
  }
  assert(coverage.every(count=>count===1));
});

test('source and output measurements preserve low-alpha artwork separately from the opaque core',async()=>{
  const {fixture,inspected}=await inspectedFixture();
  assert.equal(inspected.cells.length,16);
  assert(inspected.alpha.transparent_fraction>0.8);
  const core=build.bounds(fixture.raw,fixture.width,fixture.height);
  const full=build.bounds(fixture.raw,fixture.width,fixture.height,0);
  assert.equal(full.count-core.count,16);
  assert.equal(inspected.cells[0].count,24*24);
  assert.equal(inspected.cells[0].border,0);
});

test('packing requires explicit roots, a finite scale and a nonclipped final anchor',async()=>{
  assert.equal(typeof build.prepare,'function');
  const {fixture,inspected}=await inspectedFixture();
  for(const config of [null,{scale:1,roots:[]},{scale:0,roots:fixture.roots},{scale:NaN,roots:fixture.roots},{scale:Infinity,roots:fixture.roots}]) {
    await assert.rejects(build.prepare(inspected,config));
  }
  for(const anchor of [null,undefined,"missing",[NaN,0],[0,Infinity],[0]]) {
    const badRoots=fixture.roots.map(root=>root.slice());badRoots[4]=anchor;
    await assert.rejects(build.prepare(inspected,{scale:1,roots:badRoots}),/anchor/i);
  }
  const clippedRoots=fixture.roots.map(root=>[root[0]+1000,root[1]]);
  await assert.rejects(build.prepare(inspected,{scale:1,roots:clippedRoots}),/clips|anchor|outside/i);
});

test('atlas packing round-trips every aligned RGBA frame including alpha=1 at unit scale',async()=>{
  assert.equal(typeof build.prepare,'function');
  const {fixture,inspected}=await inspectedFixture();
  const result=await build.prepare(inspected,{scale:1,roots:fixture.roots});
  assert.equal(result.frames.length,16);
  assert.equal(result.fixed_scale,1);
  assert.equal(result.atlas_sha256,sha(result.atlas));
  for(const frame of result.frames) {
    assert.deepEqual(frame.source_root,fixture.roots[frame.index]);
    assert.equal(frame.placement[0],242);
    assert.equal(frame.placement[1],294);
    assert.equal(frame.placement[2],26);
    assert.equal(frame.placement[3],26);
    const decoded=await sharp(result.atlas).extract({left:frame.index%4*512,top:Math.floor(frame.index/4)*384,width:512,height:384}).raw().toBuffer();
    assert.equal(sha(decoded),frame.output_rgba_sha256);
    const pixel=(294*512+242)*4;
    assert.deepEqual([...decoded.subarray(pixel,pixel+4)],[219,33,95,1]);
    assert.equal(build.bounds(decoded,512,384,0).border,0);
    const [l,t,r,b]=frame.source_preserved_bbox;
    const source=await sharp(inspected.bytes).extract({left:l,top:t,width:r-l,height:b-t}).raw().toBuffer();
    assert.equal(sha(source),frame.source_pixels_sha256);
  }
});

test('both forms expose exactly six complete directional families and 32 authored regions each',()=>{
  for(const form of ['spectral','infernal']) {
    const text=build.resource(items(form),form);
    assert.equal((text.match(/sub_resource type="AtlasTexture"/g)||[]).length,32);
    assert.equal((text.match(/"name": &"/g)||[]).length,24);
    for(const direction of DIRS) for(const stem of STEMS) {
      assert.equal(text.split(`"name": &"${stem}_${direction}"`).length-1,1);
    }
    assert.match(text,/load_steps=35/);
  }
});

test('four transformation clips reuse two authored rows with runtime-only mirroring',()=>{
  const text=build.resource([{key:'transform_ALL',frames:Array(8).fill({})}],'transform');
  assert.equal((text.match(/"name": &"transform_/g)||[]).length,4);
  for(let direction=0;direction<4;direction++) {
    const line=text.split('\n').find(line=>line.includes(`"name": &"transform_${DIRS[direction]}"`));
    assert(line);
    for(let frame=0;frame<4;frame++) assert(line.includes(`SubResource("transform_ALL_${(direction%2)*4+frame}")`));
  }
});

test('invalid texture overrides fail instead of falling back or publishing empty animations',()=>{
  for(const frames of [[-1,6,7,8],[5,6,7,16],[5,6,7,0.5],[]]) {
    assert.throws(()=>build.resource(items('spectral'),'spectral',{'spectral_E:attack':frames}),/Invalid|empty|frame/i);
  }
  const text=build.resource(items('spectral'),'spectral',{'spectral_E:attack':[5,5,7,8]});
  const line=text.split('\n').find(line=>line.includes('"name": &"attack_E"'));
  assert.equal(line.split('SubResource("spectral_E_5")').length-1,2);
  assert(!line.includes('SubResource("spectral_E_6")'));
});

test('transformation pose substitutions affect the master and its mirrored alias identically',()=>{
  const text=build.resource([{key:'transform_ALL',frames:Array(16).fill({})}],'transform',{'transform_ALL:transform_N':[4,5,5,7]});
  const north=text.split('\n').find(line=>line.includes('"name": &"transform_N"'));
  const east=text.split('\n').find(line=>line.includes('"name": &"transform_E"'));
  assert.equal(north.split('SubResource("transform_ALL_5")').length-1,2);
  assert(!north.includes('SubResource("transform_ALL_6")'));
  const west=text.split('\n').find(line=>line.includes('"name": &"transform_W"'));
  assert.equal(west.split('SubResource("transform_ALL_5")').length-1,2);
  assert(!west.includes('SubResource("transform_ALL_6")'));
  assert(east.includes('SubResource("transform_ALL_2")'));
});

test('preview durations match the simulation profile rather than suggesting faster casts',()=>{
  const profile=fs.readFileSync(path.join(ROOT,'data/visuals/paris/paris_sprite_visual_profile.gd'),'utf8');
  for(const action of ['attack','cast']) {
    const timing=new RegExp(`"${action}"\\s*:\\s*([0-9.]+)`).exec(profile);
    assert(timing,action);
    assert.equal(build.CLIPS[action].duration,Number(timing[1]),action);
  }
  const death=/death_duration_seconds\s*=\s*([0-9.]+)/.exec(profile);
  assert.equal(build.CLIPS.death.duration,Number(death[1]));
});

test('a complete committed asset set reproduces its resources, source hashes and RGBA atlas regions',{skip:!fs.existsSync(path.join(OUTPUT,'manifest.json'))},async()=>{
  const manifest=JSON.parse(fs.readFileSync(path.join(OUTPUT,'manifest.json'),'utf8'));
  assert.equal(manifest.complete,true,'Partial review artifacts are not a shippable enemy.');
  assert.equal(manifest.sheets.length,5);
  assert.equal(manifest.authored_drawings,72);
  assert.equal(manifest.animation_clip_count,52);
  assert.deepEqual(manifest.runtime_directions,build.RUNTIME_DIRECTIONS);
  for(const sheet of manifest.sheets) {
    assert.equal(sheet.source_sha256,sha(fs.readFileSync(path.join(ROOT,sheet.source))));
    assert.equal(sheet.frames.length,sheet.key==='transform_ALL'?8:16);
    const atlas=fs.readFileSync(path.join(OUTPUT,`atlas_${sheet.key}.png`));
    assert.equal(sheet.atlas_sha256,sha(atlas));
    for(const frame of sheet.frames) {
      const region=await sharp(atlas).extract({left:frame.index%4*512,top:Math.floor(frame.index/4)*384,width:512,height:384}).raw().toBuffer();
      assert.equal(sha(region),frame.output_rgba_sha256);
      assert.equal(build.bounds(region,512,384).border,0);
    }
  }
  for(const form of ['spectral','infernal','transform']) {
    const source=build.resource(manifest.sheets.filter(sheet=>sheet.key.startsWith(form+'_')),form,manifest.clip_overrides);
    assert.equal(fs.readFileSync(path.join(OUTPUT,`frames_${form}.tres`),'utf8'),source);
  }
});

test('manual extraction windows cannot omit a nonzero source pixel or duplicate a pose',async()=>{
  const fixture=syntheticRGBA();
  const stray=(21*fixture.width)*4;
  fixture.raw[stray]=120;fixture.raw[stray+1]=60;fixture.raw[stray+2]=190;fixture.raw[stray+3]=1;
  const bytes=await sharp(fixture.raw,{raw:{width:fixture.width,height:fixture.height,channels:4}}).png().toBuffer();
  const incomplete=build.windows(fixture.width,fixture.height);
  incomplete[0]=[1,0,63,64];
  await withSource(bytes,()=>assert.rejects(build.inspect('fixture',{windows:incomplete}),/window|cover|pixel|omitt|unassigned/i));
  for(const malformed of [[],build.windows(256,256).slice(1),[[0.5,0,64,64],...build.windows(256,256).slice(1)],[[0,0,257,64],...build.windows(256,256).slice(1)]]) {
    await withSource(bytes,()=>assert.rejects(build.inspect('fixture',{windows:malformed}),/window|sixteen|integer|bounds/i));
  }
  const duplicate=build.windows(fixture.width,fixture.height);
  duplicate[1]=duplicate[0];
  await withSource(bytes,()=>assert.rejects(build.inspect('fixture',{windows:duplicate}),/window|cover|overlap|pixel|omitt|unassigned/i));
});
test('the transformation sheet packs exactly eight source drawings into two atlas rows',async()=>{
  const {fixture,inspected}=await inspectedFixture(8,'transform_ALL');
  assert.equal(inspected.cells.length,8);
  assert.deepEqual(inspected.dimensions,[256,128]);
  assert.equal(inspected.source_window_coverage.omitted_nonzero_pixels,0);
  assert.equal(inspected.source_window_coverage.duplicated_nonzero_pixels,0);
  const result=await build.prepare(inspected,{scale:1,roots:fixture.roots});
  const meta=await sharp(result.atlas).metadata();
  assert.equal(meta.width,2048);
  assert.equal(meta.height,768);
  assert.equal(result.frames.length,8);
  assert.equal(result.atlas_sha256,sha(result.atlas));
});

test('mirrored body directions reference the exact same textures as their masters',()=>{
  const references=line=>[...line.matchAll(/"texture": SubResource\("([^"]+)"\)/g)].map(match=>match[1]);
  for(const form of ['spectral','infernal']) {
    const text=build.resource(items(form),form);
    assert(!text.includes(`atlas_${form}_S.png`));
    assert(!text.includes(`atlas_${form}_W.png`));
    for(const stem of STEMS) for(const [master,alias]of [['E','S'],['N','W']]) {
      const first=text.split('\n').find(line=>line.includes(`"name": &"${stem}_${master}"`));
      const second=text.split('\n').find(line=>line.includes(`"name": &"${stem}_${alias}"`));
      assert.deepEqual(references(first),references(second));
    }
  }
  assert.deepEqual(build.RUNTIME_DIRECTIONS,{E:{master:'E',flip_h:false},N:{master:'N',flip_h:false},S:{master:'E',flip_h:true},W:{master:'N',flip_h:true}});
});