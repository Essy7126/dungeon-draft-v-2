import fs from 'node:fs/promises';
import {createRequire} from 'node:module';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const config=JSON.parse(await fs.readFile(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const source=path.join(root,config.motion_source);
const require=createRequire(path.join(source,'package.json'));
const puppeteer=require('puppeteer-core');
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const revision=process.argv[2]||'sentinelle_kit_v5';
if(!/^[\w-]+$/.test(revision))throw Error('Invalid revision');
const out=path.join(root,'artifacts/dev',`spine-kit-web-${Date.now()}`);
await fs.mkdir(out,{recursive:true});
const browser=await puppeteer.launch({executablePath:findChrome(),headless:true});
const errors=[],checks=[];
try{
 const page=await browser.newPage();
 await page.setViewport({width:1440,height:1120,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));
 page.on('response',r=>{if(r.status()>=400&&!r.url().endsWith('favicon.ico'))errors.push(`${r.status()} ${r.url()}`)});
 await page.goto(`http://127.0.0.1:8734/files/${revision}/review.html`);
 await page.waitForFunction(()=>window.__kitReady===true,{timeout:25000});
 await page.waitForFunction(()=>Object.values(window.__kit.players).every(p=>p.assetManager.isLoadingComplete()));
 await new Promise(r=>setTimeout(r,900));
 const durations={idle:2.4,walk:.72,attack:.8,cast:.88,hit:.2,death:.8};
 const draw=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 for(const [action,duration]of Object.entries(durations)){
  await page.click(`[data-action="${action}"]`);
  const samples=[];
  for(const [i,fraction]of [0,.25,.5,.75,1].entries()){
   await page.evaluate(t=>window.__kit.seek(t),duration*fraction);await draw();
   const state=await page.evaluate(()=>Object.fromEntries(Object.entries(window.__kit.players).map(([d,p])=>[d,{duration:p.animationState.getCurrent(0).animation.duration,bones:Object.fromEntries(['root','torso','head','hand_right','foot_left','foot_right'].map(n=>{const b=p.skeleton.findBone(n);return[n,[b.worldX,b.worldY,b.a,b.b,b.c,b.d]]}))}])));
   samples.push(state);
   for(const d of ['E','S','W','N']){
    const canvas=await page.$(`#player-${d} canvas`);
    await canvas.screenshot({path:path.join(out,`${action}_${d}_${i}.png`)});
   }
  }
  for(const d of ['E','S','W','N']){
   const start=samples[0][d],middle=samples[2][d],end=samples[4][d];
   const diff=(a,b)=>Math.max(...Object.keys(a).flatMap(n=>a[n].map((v,i)=>Math.abs(v-b[n][i]))));
   const motion=diff(start.bones,middle.bones);
   const endpoint=diff(start.bones,end.bones);
   const durationOK=Math.abs(start.duration-duration)<.00001;
   const looping=action==='idle'||action==='walk';
   // Idle is sinusoidal: its quarter pose carries the motion.
   const moving=Math.max(motion,diff(start.bones,samples[1][d].bones))>.1;
   const endpointOK=action==='death'?endpoint>10:endpoint<.001||action==='walk'&&endpoint<.001;
   checks.push({direction:d,action,duration:start.duration,moving,endpoint_difference:endpoint,
                loop:looping,passed:durationOK&&moving&&endpointOK,samples:samples.map(s=>s[d])});
  }
 }
 // Exercise the review controls as a user would.
 await page.click('[data-direction="E"]');
 await page.select('#speed','0.25');
 await page.click('[data-action="attack"]');
 await page.evaluate(()=>window.__kit.seek(.4));await draw();
 await page.screenshot({path:path.join(out,'gallery.png'),fullPage:true});
 errors.push(...await page.evaluate(()=>window.__kit.faults));
 const report={passed:checks.length===24&&checks.every(c=>c.passed)&&errors.length===0,revision,checks,errors,reports:out};
 await fs.writeFile(path.join(out,'report.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify({passed:report.passed,clips:checks.length,failed:checks.filter(c=>!c.passed).map(c=>({direction:c.direction,action:c.action,endpoint_difference:c.endpoint_difference,moving:c.moving})),errors,reports:out}));
 process.exitCode=report.passed?0:1;
}catch(e){console.error(e);process.exitCode=1;await fs.writeFile(path.join(out,'failure.txt'),String(e));}
finally{await browser.close()}
