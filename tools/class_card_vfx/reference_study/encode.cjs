// Native Godot frames only. Does not retrieve or alter reference media.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../../..');
const out = path.join(root, 'artifacts/dev/class_card_vfx/reference_study');
const read = name => JSON.parse(fs.readFileSync(path.join(out,name),'utf8').replace(/^\uFEFF/,''));
const report = read('report.json');
const manifest = read('capture_manifest.json');
if (!report.passed || report.frames !== 216 || !manifest.stable_sources) throw Error('Native capture is incomplete.');
for (const input of manifest.inputs) {
  const hash = crypto.createHash('sha256').update(fs.readFileSync(path.join(root,input.path))).digest('hex').toUpperCase();
  if (hash !== input.sha256) throw Error(`Stale capture: ${input.path}`);
}
(async()=>{
  const files=[];
  for(const id of ['celestial','water_hand','standard']){
    const pages=[];
    // Export the full three-column comparison and its native-size row, without the playback controls.
    for(let i=0;i<72;i++){
      const file = path.join(out,id,`${String(i).padStart(3,'0')}.png`);
      const metadata = await sharp(file).metadata();
      if(metadata.width!==1440 || metadata.height!==1040) throw Error(`Wrong native viewport: ${file}`);
      pages.push(await sharp(file).extract({left:0,top:0,width:1440,height:900}).resize(1152,720).ensureAlpha().raw().toBuffer());
    }
    const file=path.join(out,`${id}.gif`);
    await sharp(Buffer.concat(pages),{raw:{width:1152,height:720*72,channels:4,pageHeight:720}})
      .gif({loop:0,delay:Array.from({length:72},(_,i)=>i%3===2?40:30),colours:128,effort:3,dither:0.5})
      .toFile(file);
    const meta=await sharp(file,{animated:true}).metadata();
    // The GIF encoder combines identical consecutive frames, preserving their delay.
    // Verify the complete timeline, not a page count that legitimately shrinks during holds.
    const duration=(meta.delay || []).reduce((total,delay)=>total+delay,0);
    if(meta.width!==1152 || meta.pageHeight!==720 || meta.pages<2 || meta.pages>72 || duration!==2400)
      throw Error(`Incomplete GIF: ${id}, ${meta.pages} pages / ${duration} ms`);
    files.push({id,file:path.relative(root,file),source_frames:72,encoded_pages:meta.pages,duration_ms:duration,bytes:fs.statSync(file).size});
    process.stdout.write(`${id}: 72 native frames, ${meta.pages} encoded pages, ${duration} ms\n`);
  }
  fs.writeFileSync(path.join(out,'encoded.json'),JSON.stringify({encoded_utc:new Date().toISOString(),files,native_report:report},null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
