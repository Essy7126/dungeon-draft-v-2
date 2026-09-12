import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/veilleur_walk_E_v5');
const cfg=JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json','utf8'));
const source=path.join(root,cfg.motion_source),req=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await req('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const report={date:new Date().toISOString(),url:'http://127.0.0.1:8734/files/veilleur_walk_E_v5/review.html',checks:[],errors:[]};
function check(name,passed,detail){report.checks.push({name,passed,detail});assert.ok(passed,name);}
try{
 const page=await browser.newPage();page.on('pageerror',e=>report.errors.push(String(e)));
 await page.setViewport({width:1440,height:1080,deviceScaleFactor:1});
 const response=await page.goto(report.url,{waitUntil:'networkidle0'});check('Page served',response.status()===200);
 await page.waitForFunction(()=>window.reviewReady===true&&window.walkState.elapsed>.2);
 check('Initial autoplay',await page.evaluate(()=>window.walkState.playing&&window.walkState.frame>=0&&window.walkState.frame<48));
 await page.evaluate(()=>window.seekWalk(0));
 const poses=[],pictures=[];
 for(let i=0;i<48;i++){
  await page.evaluate(i=>window.seekWalk(i),i);
  poses.push(await page.evaluate(()=>({reference:Number(document.getElementById('before').dataset.frame),hero:Number(document.getElementById('after').dataset.frame)})));
  pictures.push(await page.$eval('#after',c=>c.toDataURL()));
 }
 check('48 synchronized comparison states',poses.every((p,i)=>p.reference===i&&p.hero===i));
 check('48 distinct rendered frames',new Set(pictures).size===48);
 await page.evaluate(()=>window.seekWalk(36));
 const detailPictures=[];
 for(const detail of ['legs','arms','full']){
  await page.select('#detail',detail);
  check(`Detail ${detail}`,await page.evaluate(d=>window.walkState.detail===d&&window.walkState.frame===36,detail));
  detailPictures.push(await page.$eval('#after',c=>c.toDataURL()));
  if(detail!=='full'){
   await page.$eval('.comparison',e=>e.scrollIntoView({behavior:'instant'}));
   await page.screenshot({path:path.join(out,`detail_${detail}.png`)});
  }
 }
 check('Detail selections show different actual pixels',new Set(detailPictures).size===3);
 await page.evaluate(()=>window.seekWalk(47));
 await page.click('#next');check('Forward wrap',await page.evaluate(()=>window.walkState.frame===0));
 await page.click('#prev');check('Reverse wrap',await page.evaluate(()=>window.walkState.frame===47));
 await page.$eval('#frame',e=>{e.value='15';e.dispatchEvent(new Event('input',{bubbles:true}));});check('Scrubbing',await page.evaluate(()=>window.walkState.frame===15));
 await page.select('#speed','0.5');check('Slow motion selected',await page.evaluate(()=>window.walkState.speed===.5));
 await page.select('#speed','1');await page.click('#restart');await page.click('#play');
 await page.waitForFunction(()=>window.walkState.elapsed>.2);await page.click('#play');
 const frozen=await page.evaluate(()=>window.walkState.elapsed);
 await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
 check('Playback and pause',await page.evaluate(t=>window.walkState.elapsed===t&&t>.2,frozen));
 await page.evaluate(()=>window.seekWalk(12));await page.select('#mode','travel');
 const travel=await page.$eval('#floor',c=>JSON.parse(c.dataset.root));await page.select('#mode','inplace');
 const still=await page.$eval('#floor',c=>JSON.parse(c.dataset.root));
 check('World translation follows both axes',travel[0]>still[0]&&travel[1]>still[1],{travel,still});await page.select('#mode','travel');
 await page.select('#version','before');
 const oldRoot=await page.$eval('#floor',c=>c.dataset.root);
 await page.select('#version','after');
 check('Both versions have identical world translation',oldRoot===await page.$eval('#floor',c=>c.dataset.root));
 for(const background of ['sources','cendres','sanctuaire']){
  await page.select('#background',background);
  for(const version of ['before','after']){
   await page.select('#version',version);
   check(`Map ${background}/${version}`,await page.$eval('#floor',(c,w)=>c.dataset.background===w[0]&&c.dataset.version===w[1],[background,version]));
  }
  const data=await page.$eval('#floor',c=>c.toDataURL('image/png').split(',')[1]);
  await fs.writeFile(path.join(out,`map_${background}.png`),Buffer.from(data,'base64'));
 }
 await page.select('#background','sources');await page.evaluate(()=>window.seekWalk(16));
 check('Desktop overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
 await page.evaluate(()=>scrollTo(0,0));await page.screenshot({path:path.join(out,'desktop.png')});
 await page.$eval('.floor-section',e=>e.scrollIntoView({behavior:'instant'}));await page.screenshot({path:path.join(out,'floor_review.png')});
 const resources=await page.$$eval('a[href]',async links=>await Promise.all(links.filter(a=>a.origin===location.origin).map(async a=>({url:a.getAttribute('href'),status:(await fetch(a.href)).status}))));
 check('Source and downloads served',resources.every(x=>x.status===200),resources);
 check('All visible images loaded',await page.$$eval('img',images=>images.every(x=>x.complete&&x.naturalWidth>0)));
 await page.setViewport({width:390,height:844,deviceScaleFactor:1});await page.evaluate(()=>scrollTo(0,0));
 check('Mobile overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(out,'mobile.png')});
 check('No JavaScript errors',report.errors.length===0,report.errors);
}finally{await fs.writeFile(path.join(out,'verification.json'),JSON.stringify(report,null,2));await browser.close();}
console.log(JSON.stringify({passed:report.checks.filter(c=>c.passed).length,errors:report.errors}));


