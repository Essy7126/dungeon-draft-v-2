// Encode the native camera frames, with no crop, compositing or retouching.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../..');
const dir = path.join(root, 'artifacts/dev/class_card_vfx/persistence');
(async () => {
  const report = JSON.parse(fs.readFileSync(path.join(dir, 'report.json')));
  if (!report.passed || report.frames !== 60 || report.checks.some(row => !row.ok)) throw Error('Incomplete combat capture');
  const pixels = [];
  for (let i = 0; i < 60; i++) {
    const { data, info } = await sharp(path.join(dir, 'frames', `${String(i).padStart(3, '0')}.png`)).removeAlpha().raw().toBuffer({ resolveWithObject: true });
    if (info.width !== 1440 || info.height !== 950) throw Error('Unexpected viewport');
    pixels.push(data);
  }
  const output = path.join(dir, 'durable_states.gif');
  await sharp(Buffer.concat(pixels), { raw: { width: 1440, height: 950 * 60, channels: 3, pageHeight: 950 } })
    .gif({ loop: 0, delay: Array.from({ length: 60 }, (_, i) => i % 3 === 2 ? 40 : 30), colours: 256, effort: 5 }).toFile(output);
  const metadata = await sharp(output, { animated: true }).metadata();
  if (metadata.pages !== 60 || metadata.delay.reduce((a, b) => a + b, 0) !== 2000) throw Error('Wrong duration');
  const inputs = ['tools/class_card_vfx/combat_probe.gd', 'vfx/class_cards/class_card_vfx_router.gd', 'vfx/class_cards/class_card_vfx_player.gd', 'vfx/class_cards/class_card_vfx_catalog.gd', 'vfx/class_cards/class_card_vfx_ground.gd',
    ...['veil.gdshader', 'fire.gdshader', 'ground.gdshader', 'flow_noise.tres', 'white.tres'].map(p => 'vfx/class_cards/ethereal/' + p)];
  fs.writeFileSync(path.join(dir, 'encode_report.json'), JSON.stringify({ frames: 60, duration_ms: 2000, renderer: report.renderer, source: 'Unchanged Godot viewport captures; palette quantization only', scenario: report.note,
    inputs: inputs.map(p => ({ path: p, sha256: crypto.createHash('sha256').update(fs.readFileSync(path.join(root, p))).digest('hex') })) }, null, 2));
  console.log(JSON.stringify({ ok: true, frames: 60, output }));
})().catch(e => { console.error(e); process.exitCode = 1; });
