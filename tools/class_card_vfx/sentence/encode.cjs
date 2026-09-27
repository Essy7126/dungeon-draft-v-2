// Native Godot viewport frames; GIF palette quantization only.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'sharp');
const root = path.resolve(__dirname, '../../..');
const dir = path.join(root, 'artifacts/dev/class_card_vfx/sentence/combat');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async () => {
  const report = JSON.parse(fs.readFileSync(path.join(dir, 'report.json')));
  if (!report.passed || report.frames !== 126 || report.casts.length !== 2) throw Error('Incomplete native capture');
  const records = [];
  for (const variant of ['v1', 'v2']) {
    const buffers = [];
    for (let i = 0; i < 63; i++) {
      const frame = path.join(dir, variant, `${String(i).padStart(3, '0')}.png`);
      const { data, info } = await sharp(frame).removeAlpha().raw().toBuffer({ resolveWithObject: true });
      if (info.width !== 1440 || info.height !== 950) throw Error('Unexpected capture size');
      buffers.push(data);
    }
    const output = path.join(dir, `sentence_${variant}.gif`);
    await sharp(Buffer.concat(buffers), { raw: { width: 1440, height: 950 * 63, channels: 3, pageHeight: 950 } })
      .gif({ loop: 0, delay: Array.from({ length: 63 }, (_, i) => i % 3 === 2 ? 40 : 30), colours: 256, effort: 3 })
      .toFile(output);
    const meta = await sharp(output, { animated: true }).metadata();
    if (meta.delay.reduce((a, b) => a + b, 0) !== 2100) throw Error('Incorrect playback duration');
    records.push({ variant, frames: 63, duration_ms: 2100, path: output, sha256: hash(output) });
  }
  fs.writeFileSync(path.join(dir, 'encode_report.json'), JSON.stringify({ passed: true, source: 'Unchanged Godot viewport pixels, palette quantization only', outputs: records }, null, 2));
  console.log(JSON.stringify(records));
})().catch(error => { console.error(error); process.exitCode = 1; });
