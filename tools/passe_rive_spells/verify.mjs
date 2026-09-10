import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {SpellLab} from './engine.mjs';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/passe_rive_spells_v1');
const data=JSON.parse(await fs.readFile(path.join(out,'manifest.json'),'utf8'));
function advance(lab,seconds){for(let t=0;t<seconds;t+=1/240)lab.step(1/240)}
const checks=[];
const phaseCheck=new SpellLab(data);phaseCheck.cast('strike');while(!phaseCheck.active.fired)phaseCheck.step(1/240);assert.equal(phaseCheck.phase,1,'Impact must show extension, including during hitstop');checks.push('Impact pose and release event synchronized at floating-point boundary');
for(const action of data.actions){const lab=new SpellLab(data);assert(lab.cast(action.id));assert.equal(lab.cast(action.id),false,'Early duplicate cast must not interrupt action');advance(lab,action.event_ms/1000-.015);assert.equal(lab.events.filter(e=>e.type==='release').length,0);advance(lab,1.2);assert.equal(lab.events.filter(e=>e.type==='release').length,1);assert.equal(lab.active,null);const hits=lab.events.filter(e=>e.type==='hit');assert.equal(new Set(hits.map(e=>e.target)).size,hits.length,'An action cannot hit same target twice');if(['strike','shot','bash','sweep'].includes(action.id))assert(hits.length>0,`${action.id} must hit front target`);if(action.id==='dash'){assert(lab.player.x>325);assert(lab.player.x<=420,'Dash must stop before target');assert.equal(hits.length,0)}if(action.id==='guard'){assert(lab.player.shield>0);assert.equal(hits.length,0)}checks.push(`${action.id}: one release, correct impact, finishes`)}
const missed=new SpellLab(data);missed.targets.forEach(t=>t.x+=600);missed.cast('strike');advance(missed,1);assert.equal(missed.hits,0);checks.push('Melee misses outside range');
const queued=new SpellLab(data);queued.cast('strike');advance(queued,.36);assert(queued.cast('shot'));advance(queued,1.3);assert.equal(queued.casts,2);assert.equal(queued.events.filter(e=>e.type==='release').length,2);checks.push('Late input buffer plays exactly one next action');
const noGhost=new SpellLab(data);noGhost.cast('shot');advance(noGhost,.28);noGhost.reset();advance(noGhost,1);assert.equal(noGhost.hits,0);assert.equal(noGhost.projectiles.length,0);checks.push('Reset clears pending projectiles and actions');
const cfg=JSON.parse(await fs.readFile(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const source=path.join(root,cfg.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const errors=[],failed=[];
try{const page=await browser.newPage();await page.setViewport({width:1390,height:1100,deviceScaleFactor:1});page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>failed.push(r.url()));
 await page.goto('http://127.0.0.1:8734/files/passe_rive_spells_v1/review.html',{waitUntil:'networkidle0'});await page.waitForFunction(()=>window.spellLab?.ready);await page.evaluate(()=>window.spellLab.pause(true));assert.equal(await page.evaluate(()=>window.spellLab.loadedImages),37);
 await page.screenshot({path:path.join(out,'play_overview.png'),fullPage:true});
 for(const [i,a] of data.actions.entries()){await page.evaluate(()=>window.spellLab.lab.reset());await page.keyboard.press(`Digit${i+1}`);let snapshot=await page.evaluate(()=>window.spellLab.getState());assert.equal(snapshot.active,a.id);await page.evaluate(seconds=>{for(let t=0;t<seconds;t+=1/240)window.spellLab.step(1/240)},a.event_ms/1000+.025);await page.screenshot({path:path.join(out,`play_${a.id}.png`)});}
 await page.click('#vfx');await page.click('#shake');await page.select('#ground','light');await page.select('#speed','0.25');await page.evaluate(()=>{window.spellLab.lab.reset();window.spellLab.select(2);window.spellLab.setInspector(2)});await page.screenshot({path:path.join(out,'play_no_fx_light.png')});
 await page.focus('#stage');await page.evaluate(()=>window.spellLab.pause(false));await page.keyboard.down('ArrowRight');await new Promise(r=>setTimeout(r,350));await page.keyboard.up('ArrowRight');await page.evaluate(()=>window.spellLab.pause(true));assert((await page.evaluate(()=>window.spellLab.getState())).player.x>325);
 await page.click('#reset');assert.equal((await page.evaluate(()=>window.spellLab.getState())).player.x,325);checks.push('Browser: six number keys, movement, reset, no-FX, light background, slow motion');
 for(const file of ['manifest.json','poses_contact.png',...data.actions.flatMap(a=>a.frames.map(f=>f.file))])assert(await page.evaluate(async file=>(await fetch(file)).ok,file),file);
 await page.setViewport({width:390,height:844});await page.screenshot({path:path.join(out,'play_mobile.png'),fullPage:true});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),false);
 assert.deepEqual(errors,[]);assert.deepEqual(failed,[]);await fs.writeFile(path.join(out,'verification.json'),JSON.stringify({checks,loaded_images:37,mobile_no_overflow:true,console_errors:errors,failed_requests:failed,artistic_approval:false},null,2));console.log(JSON.stringify({checks,console_errors:errors,failed_requests:failed}));
}finally{await browser.close()}
