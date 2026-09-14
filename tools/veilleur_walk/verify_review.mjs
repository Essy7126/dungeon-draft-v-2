import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/veilleur_walk_E_v1');
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),req=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await req('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const report={date:new Date().toISOString(),url:'http://127.0.0.1:8734/files/veilleur_walk_E_v1/review.html',checks:[],errors:[]};
function check(name,passed,detail){report.checks.push({name,passed,detail});assert.ok(passed,name+': '+JSON.stringify(detail));}
try{
 const page=await browser.newPage();page.on('pageerror',e=>report.errors.push(String(e)));
 await page.setViewport({width:1440,height:1080,deviceScaleFactor:1});
 const response=await page.goto(report.url,{waitUntil:'networkidle0'});check('Page served',response.status()===200);
 await page.waitForFunction(()=>window.reviewReady===true);
 await page.evaluate(()=>window.seekWalkFrame(0));
 check('Desktop overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 for(const [version,n]of [['painted',12],['guide',48]]){
  await page.select('#version',version);
  const hashes=[];
  for(let i=0;i<n;i++){
   await page.evaluate(i=>window.seekWalkFrame(i),i);
   const status=await page.$eval('#map',c=>({index:Number(c.dataset.frame),version:c.dataset.version}));
   check(`Pose ${version}/${i}`,status.index===i&&status.version===version,status);
   hashes.push(await page.$eval('#detail',c=>c.toDataURL()));
  }
  check(`Distinct drawings ${version}`,new Set(hashes).size===n);
  await page.click('#next');check(`Loop boundary ${version}`,await page.evaluate(()=>window.walkState.frame===0));
  await page.click('#prev');check(`Previous boundary ${version}`,await page.evaluate(n=>window.walkState.frame===n-1,n));
 }
 await page.select('#version','painted');await page.select('#mode','travel');
 for(const bg of ['sources','cendres','sanctuaire']){
  await page.select('#background',bg);await page.evaluate(()=>window.seekWalkFrame(6));
  check(`Background ${bg}`,await page.$eval('#map',(c,bg)=>c.dataset.background===bg,bg));
  for(const [id,prefix]of [['map','integration'],['native','detail']]){
   const data=await page.$eval('#'+id,c=>c.toDataURL('image/png').split(',')[1]);
   await fs.writeFile(path.join(out,`${prefix}_${bg}.png`),Buffer.from(data,'base64'));
  }
 }
 await page.select('#background','sources');await page.evaluate(()=>window.seekWalkFrame(3));
 const traveling=await page.$eval('#map',c=>JSON.parse(c.dataset.root));
 await page.select('#mode','inplace');const still=await page.$eval('#map',c=>JSON.parse(c.dataset.root));
 check('World translation in both projected axes',traveling[0]>still[0]&&traveling[1]>still[1],{traveling,still});
 await page.select('#speed','0.5');check('Slow motion',await page.evaluate(()=>window.walkState.speed===.5));
 await page.select('#speed','1');await page.select('#mode','travel');await page.click('#restart');
 await page.click('#play');await page.waitForFunction(()=>window.walkState.elapsed>.2);
 await page.click('#play');const paused=await page.evaluate(()=>window.walkState.elapsed);
 await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
 check('Pause freezes playback',await page.evaluate(t=>window.walkState.elapsed===t,paused));
 await page.evaluate(()=>window.seekWalkFrame(0));await page.click('#next');check('Next pose',await page.evaluate(()=>window.walkState.frame===1));
 await page.$eval('#frame',input=>{input.value='8';input.dispatchEvent(new Event('input',{bubbles:true}));});
 check('Scrubbing',await page.evaluate(()=>window.walkState.frame===8));
 const resources=await page.$$eval('a[href]',async list=>await Promise.all(list.filter(a=>a.origin===location.origin&&!a.hash).map(async a=>({href:a.getAttribute('href'),status:(await fetch(a.href)).status}))));
 check('Downloads available',resources.every(r=>r.status===200),resources);
 await page.evaluate(()=>window.seekWalkFrame(6));await page.screenshot({path:path.join(out,'desktop.png')});
 for(let i=0;i<12;i++){
  await page.evaluate(i=>window.seekWalkFrame(i),i);
  for(const id of ['detail','native']){
   const data=await page.$eval('#'+id,c=>c.toDataURL('image/png').split(',')[1]);
   await fs.writeFile(path.join(out,`review_${id}_${String(i).padStart(2,'0')}.png`),Buffer.from(data,'base64'));
  }
 }
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});await page.evaluate(()=>scrollTo(0,0));
 check('Mobile overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(out,'mobile.png')});
 check('No JavaScript error',report.errors.length===0,report.errors);
}finally{await fs.writeFile(path.join(out,'verification.json'),JSON.stringify(report,null,2));await browser.close();}
console.log(JSON.stringify({passed:report.checks.filter(c=>c.passed).length,errors:report.errors}));
