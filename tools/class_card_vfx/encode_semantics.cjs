// Only encodes complete, unchanged native Godot frames; no compositing or retouching.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../..');
const extension = process.argv.includes('--extension');
const power = process.argv.includes('--power');
const dir = path.join(root, 'artifacts/dev/class_card_vfx', power ? 'power' : extension ? 'extension' : 'semantics');
const ids = power ? ['a_reap', 'g_bastion', 'g_crash', 'r_scatter', 'r_bounty', 't_cataclysm', 't_hourglass', 'a_stasis'] : extension ? ['a_reap', 'g_bastion', 'g_hook', 'r_net', 'r_scatter', 't_storm', 't_disrupt', 't_hourglass', 'g_fault', 'r_caltrop', 't_cataclysm', 'a_phantom'] : ['a_dagger', 't_burn', 't_flamewall', 't_glacier'];
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
(async () => {
  const report = JSON.parse(fs.readFileSync(path.join(dir, 'report.json')));
  const capture = JSON.parse(fs.readFileSync(path.join(dir, 'capture_manifest.json')));
  if (!report.passed || report.frames !== ids.length * 60 || !capture.stable_sources) throw Error('Incomplete native capture');
  for (const source of capture.inputs) {
    if (hash(path.join(root, source.path)) !== source.sha256.toLowerCase()) throw Error('Sources changed since capture: ' + source.path);
  }
  const outputs = [];
  for (const id of ids) {
    const pixels = [];
    const frames = [];
    for (let index = 0; index < 60; index++) {
      const file = path.join(dir, id, String(index).padStart(3, '0') + '.png');
      const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
      if (info.width !== 1440 || info.height !== 950) throw Error('Unexpected viewport');
      pixels.push(data);
      frames.push({ frame: index, sha256: hash(file) });
    }
    const output = path.join(dir, id + '.gif');
    await sharp(Buffer.concat(pixels), { raw: { width: 1440, height: 950 * 60, channels: 3, pageHeight: 950 } })
      .gif({ loop: 0, delay: Array.from({ length: 60 }, (_, i) => i % 3 === 2 ? 40 : 30), colours: 256, effort: 4 })
      .toFile(output);
    const metadata = await sharp(output, { animated: true }).metadata();
    if (metadata.pages !== 60 || metadata.delay.reduce((a, b) => a + b, 0) !== 2000) throw Error('Wrong playback duration');
    outputs.push({ id, frames, gif_sha256: hash(output) });
  }
  fs.writeFileSync(path.join(dir, 'encode_report.json'), JSON.stringify({
    source: 'Unchanged Godot viewport frames; GIF palette quantization only',
    renderer: report.renderer, frames: ids.length * 60, duration_ms_per_spell: 2000, inputs: capture.inputs, outputs,
  }, null, 2));
  console.log(JSON.stringify({ ok: true, spells: ids, frames: ids.length * 60, directory: dir }));
})().catch(error => { console.error(error); process.exitCode = 1; });
