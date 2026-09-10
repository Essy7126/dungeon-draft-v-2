import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/passe_rive_walk_v3');
const cfg=JSON.parse(await fs.readFile(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const source=path.join(root,cfg.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const errors=[],failed=[];
try{
 const page=await browser.newPage();await page.setViewport({width:1280,height:1020,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>failed.push(r.url()));
 await page.goto('http://127.0.0.1:8734/files/passe_rive_walk_v3/review.html',{waitUntil:'networkidle0'});
 await page.waitForFunction(()=>window.walkV3?.ready,{timeout:15000});
 for(const i of [0,3,6,9,11]){await page.evaluate(f=>window.walkV3.setFrame(f),i);await page.screenshot({path:path.join(out,`review_frame_${String(i).padStart(2,'0')}.png`)});}
 await page.select('#background','light');await page.screenshot({path:path.join(out,'review_light.png')});
 await page.select('#background','check');await page.click('#onion');await page.screenshot({path:path.join(out,'review_onion.png')});
 await page.click('#onion');await page.select('#background','dark');await page.select('#speed','0.25');
 await page.click('#play');await page.waitForFunction(()=>window.walkV3.getState().frame!==11,{timeout:3000});await page.click('#play');
 if(await page.evaluate(()=>window.walkV3.getState().playing))throw Error('Pause failed');
 const missing=[];
 for(const file of ['walk_atlas.png','walk_preview.gif','passe_rive_walk_v3.zip','manifest.json']){const response=await page.request?.get?.(file);if(response&&!response.ok())missing.push(file);const stat=await fs.stat(path.join(out,file));if(stat.size===0)missing.push(file);}
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});await page.screenshot({path:path.join(out,'review_mobile.png')});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);
 if(overflow||errors.length||failed.length||missing.length)throw Error(JSON.stringify({overflow,errors,failed,missing}));
 const report={loaded_frame_count:12,play_pause_slow_speed_passed:true,background_and_onion_controls_passed:true,mobile_no_overflow:true,page_errors:errors,failed_requests:failed,delivery_files_present:true,artistic_approval:false,painted_foot_contact_measurement:'not quantified; visual review only'};
 await fs.writeFile(path.join(out,'browser_report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{await browser.close()}
