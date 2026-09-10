import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/passe_rive_walk_audit');
const cfg=JSON.parse(await fs.readFile(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const source=path.join(root,cfg.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const errors=[],failed=[];
try{
 const page=await browser.newPage();await page.setViewport({width:1280,height:1050,deviceScaleFactor:1});
 page.on('pageerror',e=>errors.push(e.message));page.on('requestfailed',r=>failed.push(r.url()));
 await page.goto('http://127.0.0.1:8734/files/passe_rive_walk_audit/review.html',{waitUntil:'networkidle0'});
 await page.waitForFunction(()=>window.auditAPI?.ready,{timeout:15000});
 if(!await page.$eval('#verdict',e=>e.textContent.includes('10,3')))throw Error('Initial measured comparison unavailable');
 await page.screenshot({path:path.join(out,'audit_preview.png')});
 await page.click('[data-frame="2"]');
 if(!await page.$eval('#verdict',e=>e.textContent.includes('13,3')))throw Error('Third drawing comparison unavailable');
 await page.click('#ghost');await page.click('#alternate');
 await page.waitForFunction(()=>window.auditAPI.getFrame()===1,{timeout:3000});
 await page.waitForFunction(()=>window.auditAPI.getFrame()===0,{timeout:3000});
 await page.evaluate(()=>window.auditAPI.stop());
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);
 if(overflow||errors.length||failed.length)throw Error(JSON.stringify({overflow,errors,failed}));
 const report={page_errors:errors,failed_requests:failed,measurements_displayed:[10.3,13.3],alternating_frames_passed:true,mobile_no_overflow:true,corrected_walk_delivered:false};
 await fs.writeFile(path.join(out,'browser_report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{await browser.close()}
