import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/veilleur_walk_iso_v1');
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),req=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await req('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const report={date:new Date().toISOString(),checks:[],errors:[]};
function check(name,passed,detail){report.checks.push({name,passed,detail});assert.ok(passed,name)}
try{
 const page=await browser.newPage();page.on('pageerror',e=>report.errors.push(e.stack||String(e)));
 await page.setViewport({width:1440,height:1080,deviceScaleFactor:1});
 const response=await page.goto('http://127.0.0.1:8734/files/veilleur_walk_iso_v1/review.html',{waitUntil:'networkidle0'});
 check('Page served',response.status()===200);
 report.initial=await page.evaluate(()=>({state:window.isoState,viewKeys:typeof data!=='undefined'&&data?Object.keys(data.views):null}));
 await page.waitForFunction(()=>window.reviewReady&&window.isoState.elapsed>.1,{timeout:8000});
 check('Animated tour starts',await page.evaluate(()=>isoState.playing&&isoState.mode==='tour'));
 await page.evaluate(()=>seekIso(0));
 const hashes=[new Set(),new Set(),new Set(),new Set()];
 for(let i=0;i<48;i++){
  await page.evaluate(i=>seekIso(i),i);
  check('Four synchronized views at frame '+i,await page.$$eval('.card canvas',(cs,i)=>cs.length===4&&cs.every(c=>Number(c.dataset.frame)===i),i));
  const pictures=await page.$$eval('.card canvas',cs=>cs.map(c=>c.toDataURL()));pictures.forEach((p,j)=>hashes[j].add(p));
 }
 check('48 distinct images in every rendered view',hashes.every(x=>x.size===48));
 await page.click('#next');check('Forward wrap',await page.evaluate(()=>isoState.frame===0));
 await page.click('#prev');check('Reverse wrap',await page.evaluate(()=>isoState.frame===47));
 for(const [index,d] of ['E','S','W','N'].entries()){
  await page.evaluate(i=>{isoState.elapsed=i*3.2+.2;seekIso(12)},index);
  check('Tour displays '+d,await page.$eval('#map',(c,d)=>c.dataset.direction===d,d));
 }
 await page.evaluate(()=>seekIso(12));
 for(const d of ['E','S','N','W']){
  await page.select('#mode',d);check('Select '+d+' without resetting foot phase',await page.evaluate(d=>isoState.direction===d&&isoState.frame===12,d));
 }
 await page.select('#speed','0.25');check('Slow motion',await page.evaluate(()=>isoState.speed===.25));
 await page.select('#speed','1');await page.select('#mode','tour');await page.click('#restart');await page.click('#play');
 await page.waitForFunction(()=>isoState.elapsed>.1);await page.click('#play');const frozen=await page.evaluate(()=>isoState.elapsed);
 await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 check('Pause freezes both sprite and path',await page.evaluate(t=>isoState.elapsed===t,frozen));
 await page.select('#zoom','2');check('Detail camera',await page.evaluate(()=>isoState.zoom===2));
 await page.evaluate(()=>seekIso(30));await page.screenshot({path:path.join(out,'browser_detail.png')});
 await page.select('#zoom','1');await page.evaluate(()=>seekIso(12));
 await page.screenshot({path:path.join(out,'browser_desktop.png')});
 check('Desktop has no horizontal overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 const links=await page.$$eval('a[href]',as=>Promise.all(as.map(async a=>({url:a.getAttribute('href'),status:(await fetch(a.href)).status}))));
 check('All delivery links available',links.every(x=>x.status===200),links);
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});
 check('Mobile has no horizontal overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.screenshot({path:path.join(out,'browser_mobile.png')});
 check('No browser exceptions',report.errors.length===0,report.errors);
 report.passed=true;
}catch(error){report.passed=false;report.errors.push(String(error));process.exitCode=1}
finally{await browser.close();await fs.writeFile(path.join(out,'browser_report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({passed:report.passed,checks:report.checks.length,errors:report.errors}))}
