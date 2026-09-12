// Offline artifact verification; does not launch or operate a browser.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
let sharp;try{sharp=require('sharp')}catch{sharp=require(process.env.SHARP_PATH||'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp')}
const out=path.resolve(__dirname,'../../artifacts/dev/guard_animatic_v1');
(async()=>{
 const m=JSON.parse(fs.readFileSync(path.join(out,'manifest.json'))),checks=[];
 const check=(name,condition)=>{assert.ok(condition,name);checks.push(name)};
 const times=m.timeline.times_ms;
 check('Six ordered key poses ending at 500 ms',times.length===6&&times[0]===0&&times[5]===500&&times.every((x,i)=>!i||x>times[i-1]));
 for(let i=0;i<6;i++){
  const {data,info}=await sharp(path.join(out,`pose_${i}.png`)).raw().toBuffer({resolveWithObject:true});
  check(`Pose ${i}: RGBA 256x256`,info.channels===4&&info.width===256&&info.height===256);
  let core=0,empty=0;for(let j=3;j<data.length;j+=4){if(data[j]>32)core++;if(!data[j])empty++;}
  check(`Pose ${i}: decoded content and alpha`,(i===0?core===0:core>0)&&empty>40000);
 }
 check('No core clipping',m.frames.every(f=>!f.bounds||Math.min(f.bounds[0],f.bounds[1],256-f.bounds[2],256-f.bounds[3])>=8));
 check('Anchor rounding under half a source canvas pixel',m.frames.every(f=>f.registration_error.every(e=>Math.abs(e)<=.5)));
 check('Same nominal scale for every drawing',new Set(m.frames.map(f=>f.nominal_scale)).size===1);
 const gifs={};for(const [name,duration] of [['normal',1900],['slow',3400]]){
  const meta=await sharp(path.join(out,`animatic_${name}.gif`),{animated:true}).metadata();
  const total=meta.delay.reduce((a,b)=>a+b,0);check(`${name}: encoded cycle duration ${duration} ms`,total===duration);
  check(`${name}: six distinct decoded states`,meta.pages>=6);gifs[name]={pages:meta.pages,delays_ms:meta.delay,total_ms:total};
 }
 const html=fs.readFileSync(path.join(out,'review.html'),'utf8'),script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
 new vm.Script(script);checks.push('Interactive script parses');
 check('Self-contained local review has no external scripts',!/<script[^>]+src=/.test(html));
 const report={checks_passed:checks.length,checks,gifs,browser_interaction:'NOT_VERIFIED: local URL blocked by browser security policy; no workaround attempted',scope:'Encoded files, timing, geometry and syntax only. Does not validate in-game rendering, perceived fluidity or UI interactions.'};
 fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
