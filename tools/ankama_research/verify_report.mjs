import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';

const root = process.cwd();
const output = path.join(root, 'artifacts/spine_trial/ankama_character_production');
const config = JSON.parse(await fs.readFile('tools/spine_trial/toolchain.json', 'utf8'));
const source = path.join(root, config.motion_source);
const requireMotion = createRequire(path.join(source, 'package.json'));
const {findChrome} = await import(pathToFileURL(path.join(source, 'dist/spine/gif.js')));
const browser = await requireMotion('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const report = {url:'http://127.0.0.1:8734/files/ankama_character_production/review.html', checks:[], errors:[]};
report.documentSha256=createHash('sha256').update(await fs.readFile('docs/design/achilles/ankama_character_feasibility_2026-09-12.md')).digest('hex');
report.htmlSha256=createHash('sha256').update(await fs.readFile(path.join(output,'review.html'))).digest('hex');
report.checkedAt=new Date().toISOString();
function check(name, condition, details) {
  report.checks.push({name, passed:!!condition, details});
  assert.ok(condition, `${name}: ${JSON.stringify(details)}`);
}
try {
  const page = await browser.newPage();
  page.on('pageerror', error => report.errors.push(String(error)));
  await page.setViewport({width:1440,height:1050,deviceScaleFactor:1});
  const response = await page.goto(report.url,{waitUntil:'networkidle0'});
  check('Page served', response.status()===200, response.status());
  const content = await page.evaluate(() => ({
    title:document.querySelector('h1')?.textContent,
    chapters:document.querySelectorAll('article h2').length,
    sources:[...document.querySelectorAll('article ol')].at(-1)?.children.length,
    brokenAnchors:[...document.querySelectorAll('a[href^="#"]')].filter(a=>!document.getElementById(a.hash.slice(1))).map(a=>a.hash),
    duplicateIds:[...document.querySelectorAll('[id]')].map(e=>e.id).filter((id,i,all)=>all.indexOf(id)!==i),
    externalLinks:[...document.querySelectorAll('article a')].filter(a=>a.protocol==='https:').length,
    pendingTemplate:document.body.textContent.includes('__BODY__')||document.body.textContent.includes('__TOC__'),
    overflow:document.documentElement.scrollWidth>innerWidth,
    result:document.querySelector('output').textContent
  }));
  check('Complete dossier',content.chapters===15 && content.sources===18 && content.title==='Personnages de Catabase : style et production' && !content.pendingTemplate,content);
  check('Local anchors',!content.brokenAnchors.length && !content.duplicateIds.length,content);
  check('Desktop layout',!content.overflow,content.overflow);
  check('Memory example',content.result.startsWith('54 Mio')&&content.result.endsWith('96 images'),content.result);
  const download = await page.evaluate(async()=>{const response=await fetch('dossier.md');const text=await response.text();return {status:response.status,valid:text.startsWith('# Personnages de Catabase : style et production')&&text.includes('## 15. Sources')};});
  check('Dossier download',download.status===200&&download.valid,download);
  const localReferences=await page.evaluate(async()=>{
    const urls=[...new Set([...document.querySelectorAll('article a')].filter(a=>a.origin===location.origin&&!a.hash).map(a=>a.href))];
    return await Promise.all(urls.map(async url=>({url,status:(await fetch(url)).status})));
  });
  check('Local evidence links and archive',localReferences.length===9&&localReferences.every(r=>r.status===200),localReferences);
  const images=await page.$$eval('article img',imgs=>imgs.map(img=>({src:img.src,loaded:img.complete&&img.naturalWidth>0})));
  check('Historical visual evidence',images.length===2&&images.every(img=>img.loaded),images);
  await page.screenshot({path:path.join(output,'desktop.png')});
  await page.evaluate(()=>{document.querySelector('[name="width"]').value=192;document.querySelector('[name="height"]').value=192;document.querySelector('[name="width"]').dispatchEvent(new Event('input',{bubbles:true}));document.getElementById('memory-form').scrollIntoView({block:'center',behavior:'instant'});});
  check('Quarter area recalculation',(await page.$eval('output',e=>e.textContent)).startsWith('13,5 Mio'));
  await page.screenshot({path:path.join(output,'calculator.png')});
  await page.evaluate(()=>{document.querySelector('[name="width"]').value='';document.querySelector('[name="width"]').dispatchEvent(new Event('input',{bubbles:true}));});
  check('Invalid input feedback',(await page.$eval('output',e=>e.textContent)).startsWith('Renseigner'));
  await page.evaluate(()=>document.getElementById('chapitre-7').scrollIntoView({block:'start',behavior:'instant'}));
  await page.screenshot({path:path.join(output,'pipeline.png')});
  await page.setViewport({width:390,height:844,deviceScaleFactor:1});
  await page.reload({waitUntil:'networkidle0'});
  check('Mobile contents collapsed',!(await page.$eval('#contents',e=>e.open)));
  check('Mobile no body overflow',await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.evaluate(()=>window.scrollTo({top:0,behavior:'instant'}));
  await page.screenshot({path:path.join(output,'mobile.png')});
  await page.click('summary');
  await page.click('nav a[href="#chapitre-11"]');
  await page.waitForFunction(()=>location.hash==='#chapitre-11'&&!document.querySelector('#contents').open);
  check('Mobile chapter navigation',true);
  check('No JavaScript errors',!report.errors.length,report.errors);
  report.status='passed';
} catch(error) {
  report.status='failed';report.failure=String(error);process.exitCode=1;
} finally {
  await browser.close();
  await fs.writeFile(path.join(output,'verification.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({status:report.status,checks:report.checks.length,failure:report.failure,output}));
}
