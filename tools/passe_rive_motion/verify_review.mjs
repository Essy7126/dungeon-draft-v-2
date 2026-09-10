import fs from 'node:fs/promises';
import path from 'node:path';
import {createRequire} from 'node:module';
import {pathToFileURL} from 'node:url';
const root=process.cwd(),out=path.join(root,'artifacts/spine_trial/passe_rive_motion_v1');
const cfg=JSON.parse(await fs.readFile(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const source=path.join(root,cfg.motion_source),require=createRequire(path.join(source,'package.json'));
const {findChrome}=await import(pathToFileURL(path.join(source,'dist/spine/gif.js')));
const browser=await require('puppeteer-core').launch({executablePath:findChrome(),headless:true});
const sharp=require('C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const errors=[];
try{
 const page=await browser.newPage();await page.setViewport({width:1440,height:1080,deviceScaleFactor:1});page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:8734/files/passe_rive_motion_v1/review.html',{waitUntil:'networkidle0'});
 await page.waitForFunction(()=>window.reviewAPI?.getState().loaded===8,{timeout:30000});
 const idle=await page.evaluate(()=>{
  const api=window.reviewAPI,a=api.idlePixels(0),b=api.idlePixels(.8),c=api.idlePixels(3.2);let feet=0,head=0,visible=0,loop=0;
  for(let y=0;y<1536;y++)for(let x=0;x<1024;x++){
   const p=(y*1024+x)*4;let different=false,loopDifferent=false;
   for(let k=0;k<4;k++){different ||= a[p+k]!==b[p+k];loopDifferent ||= a[p+k]!==c[p+k];}
   if(different){if(y<346)feet++;if(y>=1246)head++;if(a[p+3]>10||b[p+3]>10)visible++;}if(loopDifferent)loop++;
  }return {feet_changed_pixels:feet,head_changed_pixels:head,visible_animated_pixels:visible,loop_changed_pixels:loop};
 });
 if(idle.feet_changed_pixels||idle.head_changed_pixels||idle.loop_changed_pixels||!idle.visible_animated_pixels)throw Error('Idle pin or loop verification failed '+JSON.stringify(idle));
 await page.evaluate(()=>window.reviewAPI.setTime(0));await page.screenshot({path:path.join(out,'review_top.png')});
 const layers=[],walk=await page.$('#walk');
 for(let i=0;i<8;i++){
  await page.evaluate(i=>window.reviewAPI.setTime(i*1.12/8+.00001),i);
  const im=await walk.screenshot();const small=await sharp(im).resize(320,310).png().toBuffer();layers.push({input:small,left:(i%4)*320,top:Math.floor(i/4)*310});
 }
 await sharp({create:{width:1280,height:620,channels:3,background:'#172428'}}).composite(layers).png().toFile(path.join(out,'walk_temporal_review.png'));
 await page.evaluate(()=>{document.querySelector('#scale').value='220';document.querySelector('#background').value='map';window.reviewAPI.setTime(.28)});await page.screenshot({path:path.join(out,'review_map_220.png')});
 await page.select('#background','light');await page.evaluate(()=>window.reviewAPI.setTime(.56));await page.screenshot({path:path.join(out,'review_light.png')});
 await page.click('#step');const stepped=await page.evaluate(()=>window.reviewAPI.getState().frame);if(stepped!==5)throw Error('Frame step failed');
 await page.select('#speed','0.5');await page.click('#travel');
 if(errors.length)throw Error('Browser errors: '+errors.join(';'));
 const report={loaded_frames:8,browser_errors:errors,idle,frame_step_passed:true,backgrounds:['dark','light','map'],native_atlas_verified_by_packager:true,walk_artist_approval:false};
 await fs.writeFile(path.join(out,'review_report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}finally{await browser.close()}
