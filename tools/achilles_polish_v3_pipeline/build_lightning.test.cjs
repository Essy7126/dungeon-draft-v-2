'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
let sharp;try{sharp=require('sharp');}catch{sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');}
const {prepare}=require('./build_lightning.cjs'),{extractRaw,analyze}=require('../achilles_kit_sprite_pipeline/build_effects.cjs');
const root=path.resolve(__dirname,'../..'),layout=JSON.parse(fs.readFileSync(path.join(__dirname,'lightning_layout.json'),'utf8'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
test('delivered lightning resource rebuilds identically and packs all eight native-alpha frames',async()=>{
 const built=await prepare(layout),atlas=await sharp(built.png).raw().toBuffer();
 assert.equal(built.frames.length,8);assert.equal(built.manifest.source_alpha.removed_pixels,0);
 assert.equal(built.manifest.source_alpha.source_alpha_sum,34116664);
 assert.equal(built.manifest.source_alpha.output_alpha_sum,34116664);
 assert.deepEqual(built.png,fs.readFileSync(path.join(root,'assets/vfx/achilles_polish_v3/lightning.png')));
 assert.equal(built.resource,fs.readFileSync(path.join(root,'assets/vfx/achilles_polish_v3/lightning.tres'),'utf8'));
 for(let i=0;i<8;i++){const cell=extractRaw(atlas,1024,{left:i%4*256,top:Math.floor(i/4)*256,width:256,height:256});assert.equal(sha(cell),built.frames[i].packed_rgba_sha256);const a=analyze(cell,256,256);assert.ok(a.alpha_bounds.all[0]>=12&&a.alpha_bounds.all[1]>=12);assert.ok(a.alpha_bounds.all[2]<=244&&a.alpha_bounds.all[3]<=244);}
 assert.equal((built.resource.match(/\[sub_resource type="AtlasTexture"/g)||[]).length,8);
 assert.equal((built.resource.match(/"name": &"/g)||[]).length,2);
});
test('source-window alpha including reviewed low-alpha gutters is conserved with one scale per row',async()=>{
 const built=await prepare(layout);
 assert.equal(built.frames.reduce((n,f)=>n+f.source_alpha.alpha_sum,0),34116664);
 assert.equal(new Set(built.frames.slice(0,4).map(f=>f.scale)).size,1);
 assert.equal(new Set(built.frames.slice(4).map(f=>f.scale)).size,1);
 assert.ok(built.frames[5].source_alpha.alpha_sum>built.frames[7].source_alpha.alpha_sum*5,'Large hit peak and small extinction retain different authored sizes.');
 assert.deepEqual(built.frames.map(f=>f.source_boundary_alpha),[2,1,1,1,4,5,1,1]);
});
test('modified source identity, reordered phases, overlaps and clipping are refused',async()=>{
 const copy=()=>JSON.parse(JSON.stringify(layout));
 let bad=copy();bad.sha256='0'.repeat(64);await assert.rejects(prepare(bad),/source mismatch/);
 bad=copy();bad.frames[0].frame=1;await assert.rejects(prepare(bad),/frame order/);
 bad=copy();bad.frames[1].window[0]-=1;bad.frames[1].window[2]+=1;await assert.rejects(prepare(bad),/Overlapping/);
 bad=copy();bad.common_radii[0]=50;await assert.rejects(prepare(bad),/discarded authored alpha/);
 bad=copy();bad.frames[0].boundary_alpha_max=0;await assert.rejects(prepare(bad),/clipped lightning edge/);
});
