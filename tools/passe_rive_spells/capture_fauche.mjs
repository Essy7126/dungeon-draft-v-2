// Capture the whole circular sweep at real speed, including the hit target.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),base=path.join(root,'artifacts/spine_trial/passe_rive_spells_v1'),out=path.join(base,'fauche_capture');
await fs.mkdir(out,{recursive:true});
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
try{
 const page=await browser.newPage();await page.setViewport({width:1390,height:1100,deviceScaleFactor:1});
 await page.goto('http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html',{waitUntil:'networkidle0'});await page.waitForFunction(()=>window.spellLab?.ready);
 await page.evaluate(()=>{window.spellLab.pause(true);document.getElementById('shake').checked=false});
 const layers=[];
 for(const [name,t] of [['back',.18],['front',.455]]){
  await page.evaluate(t=>{const w=window.spellLab;w.lab.reset();w.index(9);w.lab.active.t=t;w.render()},t);
  const counts=await page.evaluate(()=>{
   const w=window.spellLab,c=document.getElementById('stage').getContext('2d');
   document.getElementById('vfx').checked=true;w.render();const on=c.getImageData(0,90,665,390).data;
   document.getElementById('vfx').checked=false;w.render();const off=c.getImageData(0,90,665,390).data;
   let changed=0;for(let i=0;i<on.length;i+=4)if(Math.abs(on[i]-off[i])+Math.abs(on[i+1]-off[i+1])+Math.abs(on[i+2]-off[i+2])>12)changed++;
   document.getElementById('vfx').checked=true;w.render();return changed;
  });
  assert(counts>100,'Missing visible '+name+' trail');layers.push({name,changed:counts});
  await page.screenshot({path:path.join(base,`fauche_${name}.png`),fullPage:true});
 }
 await page.evaluate(()=>{const w=window.spellLab;w.lab.reset();w.index(9);w.render()});
 for(let i=0;i<75;i++){
  const encoded=await page.evaluate(()=>{const c=document.createElement('canvas');c.width=665;c.height=390;c.getContext('2d').drawImage(document.getElementById('stage'),0,90,665,390,0,0,665,390);const encoded=c.toDataURL('image/png').split(',')[1];window.spellLab.step(.02);return encoded});
  await fs.writeFile(path.join(out,`${String(i).padStart(3,'0')}.png`),Buffer.from(encoded,'base64'));
 }
 await fs.writeFile(path.join(base,'fauche_visual_checks.json'),JSON.stringify({layers,frames:75,fps:50},null,2));
 console.log(JSON.stringify({fauche_capture:'OK',layers,frames:75}));
}finally{await browser.close()}
