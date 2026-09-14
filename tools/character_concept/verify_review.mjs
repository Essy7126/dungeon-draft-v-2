import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(), output=path.join(root,'artifacts/spine_trial/serment_cendre_concept_v1');
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),req=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await req('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const report={date:new Date().toISOString(),url:'http://127.0.0.1:8734/files/serment_cendre_concept_v1/review.html',checks:[],errors:[]};
function check(name,passed,detail){report.checks.push({name,passed,detail});assert.ok(passed,name+': '+JSON.stringify(detail));}
try{
 const page=await browser.newPage();page.on('pageerror',e=>report.errors.push(String(e)));
 await page.setViewport({width:1440,height:1000,deviceScaleFactor:1});
 const response=await page.goto(report.url,{waitUntil:'networkidle0'});check('Page served',response.status()===200);
 await page.waitForFunction(()=>window.reviewReady===true);
 const imgs=await page.$$eval('img',list=>list.map(x=>({src:x.getAttribute('src'),loaded:x.complete&&x.naturalWidth>0})));
 check('All artwork loaded',imgs.every(i=>i.loaded),imgs);
 check('Desktop overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 check('Hero contained on desktop',await page.evaluate(()=>document.querySelector('.hero-art img').getBoundingClientRect().bottom<=document.querySelector('.hero').getBoundingClientRect().bottom));
 await page.screenshot({path:path.join(output,'desktop.png')});
 await page.$eval('#sur-les-cartes',e=>e.scrollIntoView({behavior:'instant'}));
 await page.screenshot({path:path.join(output,'map_sanctuaire.png')});
 for(const background of ['sources','cendres','sanctuaire']){
  await page.select('#background',background);
  for(const candidate of ['a','b','c'])for(const height of ['96','112','128']){
   await page.select('#candidate',candidate);await page.select('#height',height);
   const state=await page.$eval('#stage',c=>({candidate:c.dataset.candidate,background:c.dataset.background,height:c.dataset.height,pixel:c.getContext('2d').getImageData(0,0,1,1).data[3]}));
   check(`Compare ${background}/${candidate}/${height}`,state.candidate===candidate&&state.background===background&&state.height===height&&state.pixel===255,state);
  }
  await page.select('#height','112');
  await page.$eval('#stage',(c,name)=>{window.lastCanvasName=name;},background);
  const data=await page.$eval('#stage',c=>c.toDataURL('image/png').split(',')[1]);
  await fs.writeFile(path.join(output,`integration_${background}.png`),Buffer.from(data,'base64'));
  const close=await page.$eval('#native',c=>c.toDataURL('image/png').split(',')[1]);
  await fs.writeFile(path.join(output,`detail_${background}.png`),Buffer.from(close,'base64'));
 }
 const before=await page.$eval('#stage',c=>c.toDataURL());await page.click('#silhouette');
 check('Silhouette control changes actual image',before!==await page.$eval('#stage',c=>c.toDataURL()));await page.click('#silhouette');
 const ring=await page.$eval('#stage',c=>c.toDataURL());await page.click('#marker');
 check('Ground marker can be hidden',ring!==await page.$eval('#stage',c=>c.toDataURL()));await page.click('#marker');
 await page.click('[data-candidate="a"]');check('Candidate shortcut',await page.$eval('#candidate',e=>e.value)==='a');
 await page.select('#candidate','c');
 const resources=await page.$$eval('a[href]',async links=>await Promise.all(links.filter(a=>a.origin===location.origin&&!a.hash).map(async a=>({href:a.getAttribute('href'),status:(await fetch(a.href)).status}))));
 check('Download resources served',resources.every(r=>r.status===200),resources);
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});await page.evaluate(()=>scrollTo(0,0));
 check('Hero contained on mobile',await page.evaluate(()=>document.querySelector('.hero-art img').getBoundingClientRect().bottom<=document.querySelector('.hero h1').getBoundingClientRect().top));
 check('Mobile overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(output,'mobile.png')});
 check('No JavaScript error',report.errors.length===0,report.errors);
}finally{await fs.writeFile(path.join(output,'verification.json'),JSON.stringify(report,null,2));await browser.close();}
console.log(JSON.stringify({passed:report.checks.filter(c=>c.passed).length,errors:report.errors}));
