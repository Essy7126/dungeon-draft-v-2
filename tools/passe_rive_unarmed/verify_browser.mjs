import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const variant=process.argv.includes('--natural')?'passe_rive_walk_unarmed_v2':'passe_rive_walk_unarmed_v1';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial',variant),expected=variant.endsWith('v2')?60:48;
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),req=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await req('puppeteer-core').launch({executablePath:findChrome(),headless:true});
try{
 const p=await browser.newPage(),errors=[];p.on('pageerror',e=>errors.push(e.message));
 await p.setViewport({width:1280,height:1100});
 await p.goto(`http://127.0.0.1:8734/files/${variant}/review.html`,{waitUntil:'networkidle0'});
 await p.waitForFunction(()=>window.unarmedWalk?.ready);
 const state=await p.evaluate(()=>window.unarmedWalk.getState());
 if(Object.keys(state.loaded).length!==4||Object.values(state.loaded).some(n=>n!==expected))throw Error('Missing frames or directions');
 for(const d of Object.keys(state.loaded)){
  await p.evaluate(d=>{window.unarmedWalk.setDirection(d);window.unarmedWalk.setFrame(0)},d);
  await p.screenshot({path:path.join(out,`browser_${d}.png`),fullPage:true});
  await p.evaluate(i=>window.unarmedWalk.setFrame(i),expected-1);await p.click('#next');
  if((await p.evaluate(()=>window.unarmedWalk.getState())).frame!==0)throw Error('Loop wrap');
  await p.click('#play');await p.waitForFunction(()=>window.unarmedWalk.getState().frame>8);await p.click('#play');
  const before=await p.evaluate(()=>window.unarmedWalk.getState());
  await p.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  const after=await p.evaluate(()=>window.unarmedWalk.getState());
  if(after.time!==before.time)throw Error('Pause does not freeze travel and animation');
 }
 await p.click('#light');await p.click('#contacts');await p.click('#onion');
 if(expected===60){
  await p.click('#compare');
  for(const d of ['E','S','N','W']){
   await p.select('#direction',d);await p.waitForFunction(d=>window.unarmedWalk.getState().previousDir===d,{},d);
  }
  await p.screenshot({path:path.join(out,'browser_compare.png'),fullPage:true});
  await p.click('#compare');
 }
 await p.select('#speed','0.25');
 await p.setViewport({width:390,height:844});await p.screenshot({path:path.join(out,'browser_mobile.png'),fullPage:true});
 const overflow=await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);
 if(errors.length||overflow)throw Error(JSON.stringify({errors,overflow}));
 const result={loaded:state.loaded,play_pause:true,loop_wrap:true,controls:true,mobile_overflow:overflow,errors,artistic_approval:false};
 await fs.writeFile(path.join(out,'browser_verification.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}finally{await browser.close()}
