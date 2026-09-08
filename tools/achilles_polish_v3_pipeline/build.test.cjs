'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {matteBackground}=require('./matting.cjs');
const {loadLegacy,compileFrames}=require('./build.cjs');
function checker(w,h,a,b){const data=Buffer.alloc(w*h*4);for(let y=0;y<h;y++)for(let x=0;x<w;x++){const v=(Math.floor(x/2)+Math.floor(y/2))%2?a:b,p=(y*w+x)*4;data[p]=v;data[p+1]=v;data[p+2]=v+3;data[p+3]=255;}return data;}
function box(data,w,x0,y0,x1,y1,color){for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){const p=(y*w+x)*4;for(let c=0;c<4;c++)data[p+c]=color[c];}}
test('checker matting removes exterior and enclosed bow holes while preserving warm ivory',()=>{
 const w=28,h=16,data=checker(w,h,135,195);
 box(data,w,2,2,12,14,[14,9,4,255]);box(data,w,3,3,11,13,[249,240,216,255]);
 box(data,w,16,2,26,14,[14,9,4,255]);for(let y=3;y<13;y++)for(let x=17;x<25;x++){const v=(Math.floor(x/2)+Math.floor(y/2))%2?135:195;box(data,w,x,y,x+1,y+1,[v,v,v+3,255]);}
 const r=matteBackground(data,w,h,{mode:'checker',minimum:100,maximum:225,chroma:24,blue_bias:-4,hole_dark_max:158,hole_light_min:180});
 assert.equal(r.data[3],0);assert.equal(r.data[(7*w+20)*4+3],0);
 assert.deepEqual(r.data.subarray((7*w+7)*4,(7*w+7)*4+4),Buffer.from([249,240,216,255]));
 assert.deepEqual(r.data.subarray((2*w+7)*4,(2*w+7)*4+4),Buffer.from([14,9,4,255]));
});
test('enclosed white breastplate highlight is preserved even when white is one checker color',()=>{
 const w=16,h=16,data=checker(w,h,218,252);
 box(data,w,3,3,13,13,[15,8,1,255]);box(data,w,4,4,12,12,[253,253,253,255]);
 const r=matteBackground(data,w,h,{mode:'checker',minimum:170,maximum:255,chroma:24,blue_bias:-4,hole_dark_max:235,hole_light_min:245});
 assert.equal(r.data[(7*w+7)*4+3],255);assert.equal(r.data[3],0);
});
test('all retained source RGBA is byte-identical after matting',()=>{
 const w=20,h=20,data=checker(w,h,135,195);box(data,w,5,5,15,15,[234,199,149,178]);
 const r=matteBackground(data,w,h,{mode:'checker',minimum:100,maximum:225});
 let kept=0;for(let p=0;p<w*h;p++)if(r.data[p*4+3]){assert.deepEqual(r.data.subarray(p*4,p*4+4),data.subarray(p*4,p*4+4));kept++;}assert.equal(kept,100);
});
test('magenta key removes internal holes without touching red crest, teal cloth or ivory',()=>{
 const w=16,h=16,data=Buffer.alloc(w*h*4);box(data,w,0,0,w,h,[255,0,255,255]);
 for(const [x,color]of [[1,[200,35,18,255]],[5,[8,73,88,255]],[9,[249,240,220,255]]])box(data,w,x,3,x+3,12,color);
 const r=matteBackground(data,w,h,{mode:'magenta',min_red:45,min_blue:45,dominance:25});
 assert.equal(r.data[3],0);for(const x of [2,6,10])assert.deepEqual(r.data.subarray((5*w+x)*4,(5*w+x)*4+4),data.subarray((5*w+x)*4,(5*w+x)*4+4));
});
test('native transparency bypasses keys and preserves original pixels',()=>{
 const data=Buffer.from([255,0,255,255,245,245,245,255,9,7,6,32,0,0,0,0]);
 assert.deepEqual(matteBackground(data,2,2,{mode:'native'}).data,data);
});
function sheet(key,count=8){return{key,cfg:{duration_seconds:0.74},mapping:count===8?[0,1,2,3,4,5,6,7]:[0,0,0,1,2,3,3,3],frames:Array.from({length:count},(_,i)=>({index:i}))};}
test('full SpriteFrames merge preserves every untouched v2 block exactly',()=>{
 const legacy=loadLegacy(),result=compileFrames([sheet('walk_E'),sheet('bow_E')],legacy);
 assert.equal(result.count,40);assert.equal(result.preserved.length,38);
 for(const [name,block]of legacy.map)if(!['walk_E','bow_E'].includes(name))assert.ok(result.text.includes(block),name);
 assert.ok(result.text.includes('"name": &"bow_E"'));assert.ok(!result.text.includes(legacy.map.get('bow_E')));
});
test('four dedicated drawings and four shared bow bookends produce eight exact references',()=>{
 const result=compileFrames([sheet('bow_E'),sheet('bow_death_E',4)],loadLegacy(),{
  bow_death_E:{0:{sheet:'bow_E',index:0},1:{sheet:'bow_E',index:1},6:{sheet:'bow_E',index:6},7:{sheet:'bow_E',index:7}},
 });
 const match=result.text.match(/\{\n"frames": \[([^]*?)\],\n"loop": false,\n"name": &"bow_death_E"/g);
 assert.ok(match);const block=match[match.length-1].slice(match[match.length-1].lastIndexOf('{\n"frames": ['));
 const ids=[...block.matchAll(/SubResource\("([^"]+)"\)/g)].map(m=>m[1]);
 assert.deepEqual(ids,['Polish_bow_E_0','Polish_bow_E_1','Polish_bow_death_E_0','Polish_bow_death_E_1','Polish_bow_death_E_2','Polish_bow_death_E_3','Polish_bow_E_6','Polish_bow_E_7']);
 assert.equal(result.count,41);
});
test('invalid clip reference fails instead of emitting a broken resource',()=>{
 assert.throws(()=>compileFrames([sheet('bow_E')],loadLegacy(),{bow_E:{4:{sheet:'missing',index:0}}}),/Invalid clip override/);
});
test('delivered atlases declare explicit roots, fixed scales and complete selected frame sets',()=>{
 const p=path.resolve(__dirname,'../../assets/characters/Achilles/sprites_polish_v3/manifest.json');
 assert.ok(fs.existsSync(p),'Build the selected sources before running delivered-asset checks');
 const manifest=JSON.parse(fs.readFileSync(p,'utf8'));assert.ok(manifest.sheets.length>=4);
 for(const item of manifest.sheets){assert.equal(item.mapping.length,8);assert.ok(item.frames.length===4||item.frames.length===8);
 const scale=item.frames[0].scale;for(const frame of item.frames){assert.equal(frame.scale,scale);assert.equal(frame.source_root.length,2);assert.ok(frame.kept_source_pixels>2000);assert.equal(frame.sha256.length,64);}}
});

test('delivered full kit has all twenty directional clips and 112 selected source regions',()=>{
 const m=JSON.parse(fs.readFileSync(path.resolve(__dirname,'../../assets/characters/Achilles/sprites_polish_v3/manifest.json'),'utf8'));
 assert.equal(m.complete,true);assert.equal(m.clip_count,48);assert.equal(m.sheets.length,20);assert.deepEqual(m.missing_clips,[]);
 assert.equal(m.sheets.reduce((sum,s)=>sum+s.frames.length,0),112);
 assert.equal(m.legacy.preserved_clips.length,28);
 for(const stem of ['walk','bow','bow_piercing','bow_death','volley'])for(const d of ['N','E','S','W'])assert.ok(m.sheets.some(s=>s.key===stem+'_'+d));
});
test('all delivered atlas regions preserve normalized RGBA and visible canvases are never clipped',async()=>{
 const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'),crypto=require('node:crypto');
 const root=path.resolve(__dirname,'../..'),m=JSON.parse(fs.readFileSync(path.join(root,'assets/characters/Achilles/sprites_polish_v3/manifest.json'),'utf8'));
 for(const s of m.sheets){const p=path.join(root,s.atlas),meta=await sharp(p).metadata();assert.equal(meta.width,2048);assert.equal(meta.height,384*Math.ceil(s.frames.length/4));
  for(const f of s.frames){const raw=await sharp(p).extract({left:f.index%4*512,top:Math.floor(f.index/4)*384,width:512,height:384}).raw().toBuffer();
   assert.equal(crypto.createHash('sha256').update(raw).digest('hex'),f.rgba_sha256,s.key+'/'+f.index);
   let baseline=0,visible=0;for(let y=0;y<384;y++)for(let x=0;x<512;x++)if(raw[(y*512+x)*4+3]>33){assert.ok(x>0&&x<511&&y>0&&y<383,s.key+' border');baseline=Math.max(baseline,y+1);visible++;}
   assert.ok(visible>2000,s.key+' empty pose');if(s.key.startsWith('walk_'))assert.equal(baseline,320,s.key+' grounded sole');
  }
 }
});

test('optional magenta edge recovery preserves alpha and reconstructs the observed edge color',()=>{
 const w=12,h=12,data=Buffer.alloc(w*h*4);box(data,w,0,0,w,h,[255,0,255,255]);
 box(data,w,3,3,9,9,[40,22,12,255]);box(data,w,3,3,9,4,[168,10,138,255]);
 const original=Buffer.from(data),key={mode:'magenta',min_red:200,min_blue:200,dominance:25};
 const plain=matteBackground(data,w,h,key),r=matteBackground(data,w,h,{...key,edge_despill:{radius:2,minimum_excess:12}});
 assert.deepEqual(data,original,'Input original is immutable');
 assert.ok(r.report.edge_despill.corrected_pixels>0);assert.ok(r.report.edge_despill.maximum_recomposition_error<=0.5);
 for(let p=0;p<w*h;p++){assert.equal(r.data[p*4+3],plain.data[p*4+3],'Support and alpha unchanged');
  if(!r.edgeCorrections[p])assert.deepEqual(r.data.subarray(p*4,p*4+4),plain.data.subarray(p*4,p*4+4));
  else assert.ok(Math.min(r.data[p*4],r.data[p*4+2])-r.data[p*4+1]<=1,'No residual magenta excess');
 }
 const p=(3*w+5)*4;assert.ok(Math.abs(r.data[p]-80)<=2);assert.ok(Math.abs(r.data[p+1]-20)<=1);
});
test('edge recovery leaves ivory, red, petrol and protected interior colors byte-identical',()=>{
 const w=31,h=21,data=Buffer.alloc(w*h*4);box(data,w,0,0,w,h,[255,0,255,255]);
 box(data,w,2,2,29,19,[30,18,9,255]);
 for(const[x,color]of [[3,[245,231,196,255]],[8,[184,29,19,255]],[13,[15,63,70,255]],[18,[233,156,97,255]],[23,[140,32,50,255]]])box(data,w,x,2,x+3,6,color);
 box(data,w,13,9,17,13,[153,35,145,255]);
 const key={mode:'magenta',min_red:200,min_blue:200,dominance:25};
 const plain=matteBackground(data,w,h,key),r=matteBackground(data,w,h,{...key,edge_despill:{radius:2}});
 assert.deepEqual(r.data,plain.data,'Natural material edges and interior purple remain unchanged');
});
test('one-pixel contaminated bowstring stays continuous with identical opacity and footprint',()=>{
 const w=19,h=25,data=Buffer.alloc(w*h*4);box(data,w,0,0,w,h,[255,0,255,255]);
 box(data,w,9,2,10,23,[160,12,145,224]);
 const key={mode:'magenta',min_red:200,min_blue:200,dominance:25};
 const plain=matteBackground(data,w,h,key),r=matteBackground(data,w,h,{...key,edge_despill:{radius:2}});
 for(let p=0;p<w*h;p++)assert.equal(r.data[p*4+3],plain.data[p*4+3]);
 for(let y=2;y<23;y++)assert.equal(r.data[(y*w+9)*4+3],224);
 assert.equal(r.report.edge_despill.corrected_pixels,21);
});
