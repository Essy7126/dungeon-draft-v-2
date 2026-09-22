// Read-only audit of the original generated atlases; no raster editing.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require(process.env.SHARP_PATH || 'C:/Users/paolo/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '../..');
const dir = path.join(root, 'vfx/class_cards/cel/art');
const out = path.join(root, 'artifacts/dev/class_card_vfx/cel/asset_audit.json');
(async () => {
  const reports = [];
  for (const file of fs.readdirSync(dir).filter(name => name.endsWith('.png')).sort()) {
    const source = path.join(dir, file);
    const metadata = await sharp(source).metadata();
    if (!metadata.hasAlpha || metadata.width !== 1536 || metadata.height !== 1024) throw Error('Invalid cel atlas: ' + file);
    const { data, info } = await sharp(source).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const cells = Array.from({ length: 6 }, () => ({ opaque: 0, transparent: 0, edge: 0 }));
    for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
      const alpha = data[(y * info.width + x) * 4 + 3];
      const cell = cells[Math.floor(y / 512) * 3 + Math.floor(x / 512)];
      if (alpha > 155) cell.opaque++;
      if (alpha < 5) cell.transparent++;
      if (alpha > 155 && (x % 512 < 2 || x % 512 > 509 || y % 512 < 2 || y % 512 > 509)) cell.edge++;
    }
    if (cells.some(cell => cell.opaque < 500 || cell.transparent < 50000 || cell.edge > 0)) throw Error('Empty, opaque or cropped pose: ' + file);
    reports.push({ file, width: info.width, height: info.height, cells, sha256: crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex') });
  }
  if (reports.length !== 17) throw Error('Expected all 17 production sequences');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify({ passed: true, files: 17, poses: 102, atlases: reports }, null, 2));
  console.log(JSON.stringify({ passed: true, files: 17, poses: 102, report: out }));
})().catch(error => { console.error(error); process.exitCode = 1; });
