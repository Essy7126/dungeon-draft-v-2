// Native Godot frames; lossless source pixels, GIF palette quantization only.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'sharp');
const root = path.resolve(__dirname, '../../..');
const folder = path.join(root, 'artifacts/dev/class_card_vfx/permutation/combat');
const ids = ['detail', 'combat'];
(async () => {
  const report = JSON.parse(fs.readFileSync(path.join(folder, 'report.json')));
  if (!report.passed || report.frames !== 84) throw Error('Capture incomplete');
  const all = [];
  const outputs = [];
  for (const id of ids) {
    const frames = [];
    for (let i = 0; i < 42; i++) {
      const file = path.join(folder, id, `${String(i).padStart(3, '0')}.png`);
      const {data, info} = await sharp(file).removeAlpha().raw().toBuffer({resolveWithObject:true});
      if (info.width !== 1440 || info.height !== 950) throw Error('Unexpected source dimensions');
      frames.push(data);
      all.push(data);
    }
    await encode(id, frames);
  }
  await encode('permutation', all);
  async function encode(id, frames) {
    const output = path.join(folder, id + '.gif');
    await sharp(Buffer.concat(frames), {limitInputPixels:1440*950*frames.length,raw:{width:1440,height:950*frames.length,channels:3,pageHeight:950}})
      .gif({loop:0,delay:frames.map((_,i)=>i%3===2?40:30),colours:256,effort:3}).toFile(output);
    const meta = await sharp(output,{animated:true,limitInputPixels:1440*950*frames.length}).metadata();
    if (meta.pages !== frames.length || meta.delay.reduce((a,b)=>a+b,0) !== frames.length/30*1000) throw Error('Animation timing mismatch');
    outputs.push({id,path:output,frames:frames.length,duration_ms:frames.length/30*1000,
      sha256:crypto.createHash('sha256').update(fs.readFileSync(output)).digest('hex')});
  }
  fs.writeFileSync(path.join(folder,'encode_report.json'),JSON.stringify({passed:true,source:'Native Godot viewport pixels; GIF palette quantization only',outputs},null,2));
  console.log(JSON.stringify(outputs));
})().catch(error=>{console.error(error);process.exitCode=1;});

