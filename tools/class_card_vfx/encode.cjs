// Encode unchanged Godot viewport captures; no synthetic or retouched preview frames.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=path.resolve(__dirname,'../..'),dir=path.join(root,'artifacts/dev/class_card_vfx/cel/gallery');
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async()=>{
 const report=JSON.parse(fs.readFileSync(path.join(dir,'report.json')));
 const capture=JSON.parse(fs.readFileSync(path.join(dir,'capture_manifest.json')));
 if(!capture.stable_sources)throw Error('Unverified capture');
 for(const source of capture.inputs)if(hash(path.join(root,source.path))!==source.sha256.toLowerCase())throw Error('Sources changed since capture: '+source.path);
 if(report.count!==report.coverage.cards || report.coverage.missing.length || report.enemies_captured.length!==report.enemy_count || report.frames!==66)throw Error('Incomplete capture');
 const pixels=[];
 for(let i=0;i<66;i++){
  const {data,info}=await sharp(path.join(dir,'frames',`${String(i).padStart(3,'0')}.png`)).removeAlpha().raw().toBuffer({resolveWithObject:true});
  if(info.width!==1440 || info.height!==950)throw Error('Unexpected viewport');
  pixels.push(data);
 }
 await sharp(Buffer.concat(pixels),{raw:{width:1440,height:950*66,channels:3,pageHeight:950}}).gif({loop:0,delay:Array.from({length:66},(_,i)=>i%3===2?40:30),colours:256,effort:5}).toFile(path.join(dir,'card_vfx_preview.gif'));
 const metadata=await sharp(path.join(dir,'card_vfx_preview.gif'),{animated:true}).metadata();
 if(metadata.pages>66 || metadata.delay.reduce((a,b)=>a+b,0)!==2200)throw Error('Wrong duration');
 fs.writeFileSync(path.join(dir,'encode_report.json'),JSON.stringify({frames:66,duration_ms:2200,cards:report.count,enemies:report.enemy_count,renderer:report.renderer,source:'Unchanged Godot viewport captures; palette quantization only',inputs:capture.inputs,gif_sha256:hash(path.join(dir,'card_vfx_preview.gif'))},null,2));
 console.log(JSON.stringify({ok:true,frames:66,cards:report.count,path:path.join(dir,'card_vfx_preview.gif')}));
})().catch(e=>{console.error(e);process.exitCode=1;});
