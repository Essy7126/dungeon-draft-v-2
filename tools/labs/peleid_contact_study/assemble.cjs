// Assemble unmodified Godot capture frames into a review animation.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
let sharp;
try { sharp = require('sharp'); } catch {
  sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
}
const root = path.resolve(__dirname, '../../..');
const out = path.join(root, 'artifacts/dev/peleid_contact_study');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
(async () => {
  const pages = [];
  for (let i = 0; i < 84; i += 2) {
    const frame = path.join(out, 'frames', `${String(i).padStart(3, '0')}.png`);
    const result = await sharp(frame).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    if (result.info.width !== 1200 || result.info.height !== 780) throw new Error('Unexpected capture dimensions');
    pages.push(result.data);
  }
  await sharp(Buffer.concat(pages), { raw: { width: 1200, height: 780 * pages.length, channels: 4, pageHeight: 780 } })
    .gif({ loop: 0, delay: pages.map((_, i) => i % 3 === 2 ? 40 : 30), colours: 192, effort: 7 })
    .toFile(path.join(out, 'study.gif'));
  const inputs = ['project.godot', 'Study.tscn', 'recipe.json', 'contact.gdshader', 'study.gd', 'assemble.cjs']
    .map(p => path.join(__dirname, p));
  inputs.push(...['empreinte_contact', 'eclat_haut', 'eclat_milieu', 'eclat_bas']
    .map(n => path.join(root, 'art/source/vfx/peleid_fresco_v1/layers', `${n}.png`)));
  inputs.push(...[
    'art/source/vfx/peleid_fresco_v1/preparation_manifest.json',
    'art/source/characters/catabase_monsters/rejeton_braise/base_frame_E.png',
    'asset/map/painted/halts/emerald_sanctuary_v1/sanctuary.png'
  ].map(p => path.join(root, p)));
  const meta = await sharp(path.join(out, 'study.gif'), { animated: true }).metadata();
  const manifest = { inputs: inputs.map(p => ({ path: path.relative(root, p).replaceAll('\\', '/'), sha256: hash(p) })),
    gif: { frames: meta.pages, duration_ms: meta.delay.reduce((a, b) => a + b, 0), width: meta.width, height: meta.pageHeight },
    engine_report: JSON.parse(fs.readFileSync(path.join(out, 'report.json'), 'utf8')) };
  fs.writeFileSync(path.join(out, 'build_manifest.json'), JSON.stringify(manifest, null, 2));
  console.log(JSON.stringify(manifest.gif));
})().catch(error => { console.error(error); process.exitCode = 1; });
