import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/dev/sentinelle-armor-v1');
const config=JSON.parse(await fs.readFile(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const source=path.join(root,config.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const errors=[],checks=[];
try {
  const page=await browser.newPage();
  await page.setViewport({width:1400,height:1100});
  page.on('pageerror',e=>errors.push(e.message));
  page.on('response',r=>{if(r.status()>=400&&!r.url().endsWith('favicon.ico'))errors.push(r.status()+': '+r.url())});
  await page.goto('http://127.0.0.1:8734/files/sentinelle_armor_v1/review.html',{waitUntil:'networkidle0'});
  for(const d of 'ESWN') {
    await page.click(`[data-view="${d}"]`);
    await page.waitForFunction(()=>window.__review.state().ready);
    await page.click('[data-frame="13"]');
    await page.click('[data-mode="compare"]');
    await page.waitForFunction(()=>['armor','reference'].every(id=>{const im=document.getElementById(id);return im.complete&&im.naturalWidth===800}));
    const pair=await page.evaluate(()=>({state:window.__review.state(),
      images:['armor','reference'].map(id=>document.getElementById(id).getAttribute('src')),
      clip:getComputedStyle(document.getElementById('reference')).clipPath}));
    if(pair.state.direction!==d||pair.state.frame!==13||pair.state.mode!=='compare'||pair.images.some(s=>!s.endsWith(`${d}_13.jpg`)))throw new Error('Mismatched comparison: '+JSON.stringify(pair));
    checks.push({test:'synchronized_contact',...pair});
    await page.click('[data-frame="1"]');
    await page.select('#speed','1');
    await page.click('#play');
    await page.waitForFunction(()=>window.__review.state().frame===25&&!window.__review.state().playing);
    checks.push({test:'playback',...await page.evaluate(()=>window.__review.state())});
  }
  await page.click('[data-view="E"]');
  await page.waitForFunction(()=>window.__review.state().ready);
  await page.select('#speed','0.25');
  await page.click('[data-frame="1"]');
  await page.click('#play');
  await page.waitForFunction(()=>window.__review.state().frame>=5);
  await page.click('#play');
  const paused=await page.evaluate(()=>window.__review.state());
  if(paused.playing||paused.frame>=25)throw new Error('Pause/slow motion failed');
  checks.push({test:'slow_motion_pause',...paused});
  await page.click('[data-mode="reference"]');
  const referenceVisible=await page.$eval('#reference',im=>getComputedStyle(im).display!=='none'&&getComputedStyle(im).clipPath==='none');
  if(!referenceVisible)throw new Error('Reference mode hidden or clipped');
  await page.click('[data-mode="compare"]');
  await page.$eval('#wipe',el=>{el.value='27';el.dispatchEvent(new Event('input',{bubbles:true}))});
  const wipe=await page.$eval('#viewer',el=>el.style.getPropertyValue('--wipe'));
  if(wipe!=='27%')throw new Error('Comparison slider failed');
  checks.push({test:'comparison_controls',referenceVisible,wipe});
  await page.click('[data-mode="armor"]');
  await page.click('[data-frame="13"]');
  await page.screenshot({path:path.join(out,'review_desktop.png'),fullPage:true});
  await page.setViewport({width:390,height:844});
  const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
  if(overflow)throw new Error('Horizontal overflow on mobile');
  await page.screenshot({path:path.join(out,'review_mobile.png'),fullPage:true});
  checks.push({test:'mobile_width',overflow});
  errors.push(...await page.evaluate(()=>window.__review.errors()));
  const report={passed:errors.length===0,errors,checks};
  await fs.writeFile(path.join(out,'web_validation.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({passed:report.passed,errors,checks:checks.length}));
  if(!report.passed)process.exitCode=1;
} finally {await browser.close()}
