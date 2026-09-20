// Encode actual viewport captures. No generated, repainted or interpolated frames.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../../..');
const dir = path.join(root, 'artifacts/dev/ethereal_ember_study');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');

(async () => {
  const report = JSON.parse(fs.readFileSync(path.join(dir, 'capture_report.json')));
  if (report.frames !== 72 || report.fps !== 30) throw Error('Incomplete Godot capture');
  const frames = [];
  const sceneHashes = [];
  for (let i = 0; i < report.frames; i++) {
    const file = path.join(dir, 'frames', `${String(i).padStart(3, '0')}.png`);
    const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    if (info.width !== 1360 || info.height !== 860) throw Error('Wrong viewport size');
    frames.push(data);
    const scene = await sharp(file).extract({ left: 32, top: 210, width: 880, height: 435 }).raw().toBuffer();
    sceneHashes.push(crypto.createHash('sha256').update(scene).digest('hex'));
  }
  // Compare just the arena, excluding the changing timer and UI.
  if (sceneHashes[0] !== sceneHashes[71]) throw Error('Effect did not disappear completely');
  if (new Set(sceneHashes.slice(5, 35)).size < 28) throw Error('Frozen animation frames');
  const raw = { width: 1360, height: 860 * report.frames, channels: 3, pageHeight: 860 };
  for (const slow of [false, true]) {
    const delay = Array.from({ length: report.frames }, (_, i) => slow ? (i % 3 === 2 ? 60 : 70) : (i % 3 === 2 ? 40 : 30));
    const filename = slow ? 'ember_slow.gif' : 'ember_preview.gif';
    await sharp(Buffer.concat(frames), { raw }).gif({ loop: 0, delay, colours: 256, effort: 5, dither: 0.7 }).toFile(path.join(dir, filename));
    const result = await sharp(path.join(dir, filename), { animated: true }).metadata();
    if (result.pages !== 72 || result.delay.reduce((a, b) => a + b, 0) !== (slow ? 4800 : 2400)) throw Error('Incorrect encoded timing');
  }
  const sources = ['study.gd', 'ember.gd', 'ember.gdshader', 'smoke.gdshader', 'project.godot'];
  fs.writeFileSync(path.join(dir, 'encode_report.json'), JSON.stringify({
    ...report, source: 'Unmodified Godot viewport captures, GIF palette quantization only',
    loop_returns_to_empty: true, distinct_active_frames: new Set(sceneHashes.slice(5, 35)).size,
    sources: sources.map(file => ({ file, sha256: hash(path.join(__dirname, file)) }))
  }, null, 2));
  console.log(JSON.stringify({ ok: true, frames: 72, duration_ms: 2400, path: path.join(dir, 'ember_preview.gif') }));
})().catch(error => { console.error(error); process.exitCode = 1; });
