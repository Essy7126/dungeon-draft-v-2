import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/veilleur_proportions_v1');
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),req=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await req('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const report={date:new Date().toISOString(),checks:[],errors:[]};
function check(name,passed){report.checks.push({name,passed});assert.ok(passed,name);}
try{
 const page=await browser.newPage();page.on('pageerror',e=>report.errors.push(String(e)));
 await page.setViewport({width:1440,height:1000,deviceScaleFactor:1});
 const response=await page.goto('http://127.0.0.1:8734/files/veilleur_proportions_v1/review.html',{waitUntil:'networkidle0'});
 check('Page served',response.status()===200);await page.waitForFunction(()=>window.reviewReady===true);
 check('Initially paused',await page.evaluate(()=>!window.proportionState.playing&&window.proportionState.frame===0));
 const reference=await page.$eval('#reference',c=>c.toDataURL());
 for(let i=0;i<24;i++){await page.evaluate(i=>window.seekProportion(i),i);check(`Pose ${i}`,await page.evaluate(i=>window.proportionState.frame===i,i));}
 check('Reference unchanged while posing',reference===await page.$eval('#reference',c=>c.toDataURL()));
 await page.click('#opposite');check('Opposite pose control',await page.evaluate(()=>window.proportionState.frame===12));
 await page.click('#first');check('First pose control',await page.evaluate(()=>window.proportionState.frame===0));
 await page.click('#play');await page.waitForFunction(()=>window.proportionState.elapsed>.2);await page.click('#play');
 check('Playback and pause',await page.evaluate(()=>!window.proportionState.playing&&window.proportionState.elapsed>.2));
 await page.evaluate(()=>window.seekProportion(0));
 check('Desktop width',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.screenshot({path:path.join(out,'desktop.png')});
 const links=await page.$$eval('a',async as=>Promise.all(as.map(async a=>(await fetch(a.href)).status)));
 check('Local references available',links.every(x=>x===200));
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});
 check('Mobile width',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(out,'mobile.png')});
 check('No JavaScript errors',report.errors.length===0);
}finally{await fs.writeFile(path.join(out,'verification.json'),JSON.stringify(report,null,2));await browser.close();}
console.log(JSON.stringify({passed:report.checks.filter(c=>c.passed).length,errors:report.errors}));
