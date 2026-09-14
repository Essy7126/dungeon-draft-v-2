// Capture the live spell and its opponent, including levitation and both VFX colors.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/passe_rive_spells_v1/vital_capture');
await fs.mkdir(out,{recursive:true});
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
try{
 const page=await browser.newPage();await page.goto('http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html',{waitUntil:'networkidle0'});await page.waitForFunction(()=>window.spellLab?.ready);
 await page.evaluate(()=>{window.spellLab.pause(true);window.spellLab.lab.reset();window.spellLab.index(8)});
 for(let i=0;i<95;i++){
  const encoded=await page.evaluate(()=>{const canvas=document.createElement('canvas');canvas.width=450;canvas.height=370;canvas.getContext('2d').drawImage(document.getElementById('stage'),170,100,450,370,0,0,450,370);const image=canvas.toDataURL('image/png');window.spellLab.step(.02);return image.split(',')[1]});
  await fs.writeFile(path.join(out,`${String(i).padStart(3,'0')}.png`),Buffer.from(encoded,'base64'));
 }
 console.log('VITAL_CAPTURE_OK: 95 frames at 50 fps, live character and opponent');
}finally{await browser.close()}
